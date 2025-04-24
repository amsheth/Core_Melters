// C file that does simple integer division and returns the result

#include <stdio.h>

int divide(int a, int b) {
    return a / b;
}

int main() {
    int a = 10;
    int b = 2;
    int c = divide(a, b);
    int d = a + c;
    // printf("a / b = %d\n", c);
    return d;
}