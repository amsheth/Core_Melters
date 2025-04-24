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
    for(int i = 0; i < 100; i++){
        x[i] = (rand()%10000 - 5000) / 10000.0;
        y[i] = (rand()%10000 - 5000) / 10000.0;
        z[i] = (rand()%10000 - 5000) / 10000.0;
    }

    int point_dist = 0;

    // Find number of points with .25
    for(float i = 0; i < 1; i+=.01)
        for(float j = 0; j < 1; j+=.01)
            for(float k = 0; k < 1; k+=.01){
                for(int a = 0; a < 100; a ++){
                    if(sq(x[a] - i) + sq(y[a] - j) + sq(z[a] - k) < .25)
                        point_dist += 1;
                }
            }
    
    return point_dist > 1000;
    
}
