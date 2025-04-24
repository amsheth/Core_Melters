#include <stdio.h>
#include <stdlib.h>

static volatile float x[100];
static volatile float y[100];
static volatile float z[100];

float dist[10000];

float sq(float a){
    return a * a;
}

int main(void) {
    srand(1);
    for(int i = 0; i < 100; i++){
        x[i] = (rand()%10000 - 5000) / 10000.0;
        y[i] = (rand()%10000 - 5000) / 10000.0;
        z[i] = (rand()%10000 - 5000) / 10000.0;

        int index = rand() % i;

        //if(index % 2 == 1)
            goto NO_DOUBLE;
        
        x[index] *= 2;

        NO_DOUBLE:
         x[index] += 2;
    }
    
}
