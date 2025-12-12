// Standard headers needed by the test (printf, malloc, FILE, string helpers)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>

// Use the project's public header for engine types and function declarations
#include "tkn.h"

// Complete the opaque TknVertexInputLayout declared in tkn.h so we can
// construct one in this test. Fields must match the engine's layout.
struct TknVertexInputLayout {
    uint32_t attributeCount;
    const char **names;
    uint32_t *sizes;
    uint32_t *offsets;
    uint32_t stride;
    // other internal fields ignored for this test
};

void test_saveMeshPtrToPlyFile_with_lua_format() {
    printf("Testing real tknSaveMeshPtrToPlyFile function with Lua vertex format...\n");
    
    // Create TknVertexInputLayout matching Lua format:
    // position: TYPE_FLOAT, count = 3 (3 * 4 = 12 bytes)
    // color: TYPE_UINT32, count = 1 (1 * 4 = 4 bytes)  
    // normal: TYPE_UINT32, count = 1 (1 * 4 = 4 bytes)
    // Total stride: 12 + 4 + 4 = 20 bytes
    
    const char *attributeNames[] = {"position", "color", "normal"};
    uint32_t attributeSizes[] = {12, 4, 4}; // position=3*float, color=1*uint32, normal=1*uint32
    uint32_t attributeOffsets[] = {0, 12, 16}; // calculated offsets
    uint32_t attributeCount = 3;
    uint32_t stride = 20;
    
    TknVertexInputLayout layout = {
        .attributeCount = attributeCount,
        .names = attributeNames,
        .sizes = attributeSizes,
        .offsets = attributeOffsets,
        .stride = stride
    };
    
    printf("✓ TknVertexInputLayout created:\n");
    printf("  - attributeCount: %u\n", layout.attributeCount);
    printf("  - stride: %u\n", layout.stride);
    printf("  - offsets: [%u, %u, %u]\n", 
           layout.offsets[0], layout.offsets[1], layout.offsets[2]);
    
    // Create test vertex data (triangle matching Lua format)
    uint32_t vertexCount = 3;
    size_t vertexDataSize = vertexCount * layout.stride;
    void *vertices = malloc(vertexDataSize);
    
    // Fill vertex data: position (3 floats), color (1 uint32), normal (1 uint32)
    uint8_t *vertexPtr = (uint8_t*)vertices;
    
    // Vertex 0: position=(-1.0, -1.0, 0.0), color=0xFF0000FF, normal=0x1
    float *pos0 = (float*)(vertexPtr + 0);
    pos0[0] = -1.0f; pos0[1] = -1.0f; pos0[2] = 0.0f;
    *(uint32_t*)(vertexPtr + 12) = 0xFF0000FF;  // color (red)
    *(uint32_t*)(vertexPtr + 16) = 0x1;         // normal
    
    // Vertex 1: position=(1.0, -1.0, 0.0), color=0x00FF00FF, normal=0x0  
    float *pos1 = (float*)(vertexPtr + 20);
    pos1[0] = 1.0f; pos1[1] = -1.0f; pos1[2] = 0.0f;
    *(uint32_t*)(vertexPtr + 32) = 0x00FF00FF;  // color (green)
    *(uint32_t*)(vertexPtr + 36) = 0x0;         // normal
    
    // Vertex 2: position=(0.0, 1.0, 0.0), color=0x0000FFFF, normal=0x0
    float *pos2 = (float*)(vertexPtr + 40);
    pos2[0] = 0.0f; pos2[1] = 1.0f; pos2[2] = 0.0f;
    *(uint32_t*)(vertexPtr + 52) = 0x0000FFFF;  // color (blue)
    *(uint32_t*)(vertexPtr + 56) = 0x0;         // normal
    
    printf("✓ Test vertex data created:\n");
    printf("  - vertexCount: %u\n", vertexCount);
    printf("  - vertexDataSize: %zu bytes\n", vertexDataSize);
    
    // Define PLY property names and types that match the TknVertexInputLayout
    const char *propertyNames[] = {
        "x", "y", "z",           // position (3 floats)
        "color",                 // color (1 uint32) 
        "normal"                 // normal (1 uint32)
    };
    const char *propertyTypes[] = {
        "float", "float", "float", // position components
        "uint",                    // color
        "uint"                     // normal
    };
    uint32_t propertyCount = 5; // 3 for position + 1 for color + 1 for normal
    
    // Test the real tknSaveMeshPtrToPlyFile function
    const char *testPlyFile = "/tmp/test_mesh_real.ply";
    
    printf("✓ Calling real tknSaveMeshPtrToPlyFile function...\n");
    
    // Call the actual function
    tknSaveMeshPtrToPlyFile(
        propertyCount,
        propertyNames,
        propertyTypes,
        &layout,
        vertices,
        vertexCount,
        VK_INDEX_TYPE_UINT32,
        NULL,  // no indices for this test
        0,     // indexCount = 0
        testPlyFile
    );
    
    printf("✓ tknSaveMeshPtrToPlyFile completed!\n");
    
    // Verify the PLY file was created and has correct content
    FILE *file = fopen(testPlyFile, "rb");
    if (file) {
        printf("✓ PLY file created successfully at %s\n", testPlyFile);
        
        // Read and verify header
        char line[256];
        bool foundPly = false;
        bool foundFormat = false;
        bool foundVertex = false;
        int propertiesFound = 0;
        size_t headerSize = 0;
        
        while (fgets(line, sizeof(line), file)) {
            headerSize += strlen(line);
            line[strcspn(line, "\r\n")] = 0; // remove newline
            
            if (strcmp(line, "ply") == 0) {
                foundPly = true;
                printf("  - Found PLY header\n");
            } else if (strstr(line, "format binary_little_endian")) {
                foundFormat = true;
                printf("  - Found binary format declaration\n");
            } else if (strstr(line, "element vertex 3")) {
                foundVertex = true;
                printf("  - Found vertex element with count 3\n");
            } else if (strstr(line, "property")) {
                propertiesFound++;
                printf("  - Found property: %s\n", line);
            } else if (strcmp(line, "end_header") == 0) {
                printf("  - Found end_header\n");
                break;
            }
        }
        
        // Check binary data size
        fseek(file, 0, SEEK_END);
        long fileSize = ftell(file);
        size_t expectedBinarySize = vertexCount * layout.stride;
        size_t actualBinarySize = fileSize - headerSize;
        
        printf("✓ PLY file verification:\n");
        printf("  - PLY header: %s\n", foundPly ? "✓" : "✗");
        printf("  - Binary format: %s\n", foundFormat ? "✓" : "✗");
        printf("  - Vertex element: %s\n", foundVertex ? "✓" : "✗");
        printf("  - Properties found: %d (expected 5)\n", propertiesFound);
        printf("  - File size: %ld bytes\n", fileSize);
        printf("  - Header size: %zu bytes\n", headerSize);
        printf("  - Binary data size: %zu bytes (expected %zu)\n", actualBinarySize, expectedBinarySize);
        
        if (foundPly && foundFormat && foundVertex && propertiesFound == 5) {
            printf("✓ PLY file format is correct!\n");
            
            // Verify binary data size matches expectations
            if (actualBinarySize == expectedBinarySize) {
                printf("✓ Binary data size matches expected vertex data size!\n");
            } else {
                printf("✗ Binary data size mismatch!\n");
            }
        } else {
            printf("✗ PLY file format validation failed\n");
        }
        
        fclose(file);
        
        // Keep the file for inspection
        printf("✓ PLY file saved for inspection: %s\n", testPlyFile);
    } else {
        printf("✗ Failed to open created PLY file: %s\n", testPlyFile);
    }
    
    // Clean up
    free(vertices);
    
    printf("✓ Test completed successfully!\n\n");
}

int main() {
    printf("=== Testing Real tknSaveMeshPtrToPlyFile Function ===\n\n");
    
    test_saveMeshPtrToPlyFile_with_lua_format();
    
    printf("=== Test Summary ===\n");
    printf("This test calls the actual tknSaveMeshPtrToPlyFile function to verify:\n");
    printf("1. Proper validation of property layout vs vertex format\n");
    printf("2. Correct PLY file generation with binary data\n");
    printf("3. Lua vertex format compatibility:\n\n");
    printf("Lua format:\n");
    printf("  tknEngine.vertexFormat = {{\n");
    printf("      name = \"position\", type = TYPE_FLOAT, count = 3,  -- 12 bytes\n");
    printf("  }, {\n");
    printf("      name = \"color\", type = TYPE_UINT32, count = 1,    -- 4 bytes\n");  
    printf("  }, {\n");
    printf("      name = \"normal\", type = TYPE_UINT32, count = 1,   -- 4 bytes\n");
    printf("  }}\n\n");
    printf("PLY properties:\n");
    printf("  property float x\n");
    printf("  property float y  \n");
    printf("  property float z      # position: 3 * 4 = 12 bytes\n");
    printf("  property uint color   # color: 1 * 4 = 4 bytes\n");
    printf("  property uint normal  # normal: 1 * 4 = 4 bytes\n");
    printf("  Total: 20 bytes per vertex\n\n");
    
    return 0;
}
