#include <stdio.h>
#include <stdlib.h>

int fib(int);
int a(int);
int b(int);
int setup();
int switchr(int a);



static _Bool ary[20];

int main(void) {
    int ret = 0;
    ret += fib(20);
    ret += a(100);
    ret += setup();
    ret += switchr(ret % 4);
    
    return ret;
}

int fib(int n) {
    if(n == 1 || n == 0)
        return 1;
    else
        return fib(n - 1) + fib( n - 2);
}

int a(int n){
    if(n < 0)
        return 0;
    return b(n - 1);
}

int b(int n){
    if(n <= 0)
        return 0;
    return a(n - 2);
}

int setup(){
    for(int i=0; i < 20 - 4; i++){
        int * a = (int*)(ary + i);
        *a += 1;
    }
    return ary[5];
}

int switchr(int a){
    switch(a){
        case(1):
            return 1;
        case(2):
            return 0;
        case(3):
            return 3;
        case(4):
            return 2;
        default:
            return 3;
    }
}
