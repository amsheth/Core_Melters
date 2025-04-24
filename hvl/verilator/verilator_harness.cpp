#define TOPLEVEL top_tb

#include <iostream>
#include <sstream>
#include <stdint.h>
#include <stdlib.h>

#include "Vtop_tb.h"
#include <verilated.h>

typedef Vtop_tb dut_t;

VerilatedContext* contextp;
dut_t* dut;
uint64_t clk_half_period = 0;

void tick(dut_t* dut) {
    contextp->timeInc(clk_half_period);
    dut->clk ^= 1;
    dut->eval();
}

void tickn(dut_t* dut, int cycles) {
    for (int i = 0; i < cycles * 2; i++) {
        tick(dut);
    }
}

uint64_t get_int_plusarg(std::string arg) {
    std::string s(contextp->commandArgsPlusMatch(arg.c_str()));
    std::replace(s.begin(), s.end(), '=', ' ');
    std::stringstream ss(s);
    std::string p;
    uint64_t retval;
    ss >> p;
    ss >> retval;
    return retval;
}

uint64_t funny_stol(std::string s) {
    std::stringstream ss(s);
    uint64_t retval;
    ss >> retval;
    return retval;
}

int main(int argc, char** argv, char** env) {
    contextp = new VerilatedContext;

    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);
    contextp->fatalOnError(false);

    try {
        clk_half_period = get_int_plusarg("CLOCK_PERIOD_PS_ECE411") / 2;
    } catch (const std::exception& e) {
        std::cerr << "TB Error: Invalid command line arg" << std::endl;
        return 1;
    }

    dut = new dut_t;

    dut->clk = 1;
    dut->rst = 1;

    tickn(dut, 2);

    dut->rst = 0;

    while (!contextp->gotFinish()) {
        tickn(dut, 1);
    }

    dut->final();
    contextp->statsPrintSummary();
    return contextp->gotError() ? EXIT_FAILURE : 0;
}
