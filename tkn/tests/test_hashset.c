#include <stdio.h>
#include <string.h>
#include "tknCore.h"

typedef struct
{
    int id;
    float value;
} MyStruct;

static void test_struct_hashset()
{
    printf("--- struct hashset test ---\n");
    TknHashSet set = tknCreateHashSet(sizeof(MyStruct));
    MyStruct a = {1, 3.14f};
    MyStruct b = {2, 2.71f};
    MyStruct c = {3, 1.23f};
    tknAddToHashSet(&set, &a);
    tknAddToHashSet(&set, &b);
    tknAddToHashSet(&set, &c);
    printf("Contains a? %d\n", tknContainsInHashSet(&set, &a));
    printf("Contains b? %d\n", tknContainsInHashSet(&set, &b));
    printf("Contains c? %d\n", tknContainsInHashSet(&set, &c));
    printf("Iterate through struct hashset:\n");
    for (size_t i = 0; i < set.capacity; i++)
    {
        TknListNode *node = set.nodePtrs[i];
        while (node)
        {
            MyStruct *data = (MyStruct *)node->data;
            printf("id=%d, value=%f\n", data->id, data->value);
            node = node->pNextNode;
        }
    }
    tknDestroyHashSet(set);
}

static void test_pointer_hashset()
{
    printf("--- pointer hashset test ---\n");
    TknHashSet set = tknCreateHashSet(sizeof(int *));
    int x = 42, y = 43, z = 44;
    void *px = &x, *py = &y, *pz = &z;
    tknAddToHashSet(&set, &px);
    tknAddToHashSet(&set, &py);
    tknAddToHashSet(&set, &pz);
    printf("Contains px:%p? %d\n", px, tknContainsInHashSet(&set, &px));
    printf("Contains py:%p? %d\n", py, tknContainsInHashSet(&set, &py));
    printf("Contains pz:%p? %d\n", pz, tknContainsInHashSet(&set, &pz));
    printf("Iterate through pointer hashset:\n");
    for (size_t i = 0; i < set.capacity; i++)
    {
        TknListNode *node = set.nodePtrs[i];
        while (node)
        {
            void *ptr = *(void **)node->data;
            printf("ptr=%p, *ptr=%d\n", ptr, *(int *)ptr);
            node = node->pNextNode;
        }
    }
    tknDestroyHashSet(set);
}

int main()
{
    test_struct_hashset();
    test_pointer_hashset();
    return 0;
}
