#include <stdio.h>
#include <limits.h> // For INT_MAX, INT_MIN

//citing chet gheh pheh theh

void test_multiplication(int a, int b) {
    long long result = (long long)a * (long long)b;
    // printf("Multiplying %d * %d = %lld\n", a, b, result);
}

void test_division(int a, int b) {
    if (b == 0) {
        // printf("Cannot divide by zero: %d / %d\n", a, b);
    } else {
        int result = a / b;
        int remainder = a % b;
        // printf("Dividing %d / %d = %d, Remainder = %d\n", a, b, result, remainder);
    }
}

void extensive_tests() {
    // Test range of values
    // printf("Testing multiplication, division, and remainder...\n");

    int test_values[] = {0, 1, -1, 2, -2, 10, -10, 100, -100, INT_MAX, INT_MIN, 1000, -1000};

    // Test multiplication
    for (unsigned int i = 0; i < sizeof(test_values) / sizeof(test_values[0]); i++) {
        for (unsigned int j = 0; j < sizeof(test_values) / sizeof(test_values[0]); j++) {
            test_multiplication(test_values[i], test_values[j]);
        }
    }

    // Test division and modulus
    for (unsigned int i = 0; i < sizeof(test_values) / sizeof(test_values[0]); i++) {
        for (unsigned int j = 0; j < sizeof(test_values) / sizeof(test_values[0]); j++) {
            test_division(test_values[i], test_values[j]);
        }
    }

    // Test edge case with large values
    test_multiplication(INT_MAX, 2);
    test_multiplication(INT_MIN, 2);

    // Test small numbers
    test_division(3, 2);
    test_division(3, -2);
    test_division(-3, 2);
    test_division(-3, -2);

    // Test division by 1 and -1
    test_division(5, 1);
    test_division(5, -1);
    test_division(-5, 1);
    test_division(-5, -1);

    // Test division by zero
    test_division(10, 0);
    test_division(-10, 0);

    // Test modulus operations
    for (int i = 0; i < sizeof(test_values) / sizeof(test_values[0]); i++) {
        for (int j = 1; j < sizeof(test_values) / sizeof(test_values[0]); j++) { // Skip j = 0 for modulus
            int remainder = test_values[i] % test_values[j];
            // printf("Modulus %d %% %d = %d\n", test_values[i], test_values[j], remainder);
        }
    }
}

int main() {
    extensive_tests();
    return 0;
}
