# Verilator

A fast, cycle-based simulator.

# Why use Verilator?

One of the biggest gripes we tend to have with VCS is its runtime - VCS does a
lot of event management under the hood, and as a result takes a very long time
to simulate big programs like Coremark. However in ECE 411, when we want to see
how good our architectural changes are in terms of IPC, this can be prohibitive
in testing.

Enter Verilator! By simulating your design only when you tell it to (usually on
clock edges), it manages to cut down simulation time significantly - like
"running Coremark in 3 seconds" significantly. Furthermore, Verilator lets you
write C++-based simulation models and testbenches. These are compiled with all
the tricks that GCC (or Clang) has to offer, which leads to further simulation
performance gains over traditional SystemVerilog models.

There's an element of convenience here. Verilator is an open-source project,
which means that unlike VCS (which is licensed), anyone can run Verilator at
home. For ECE411, we will have some tips and tricks for getting Verilator set up
at home, but we do not *officially* support a course-staff-backed WFH
setup. This is due to the IP you will be using in `mp_ooo` - you do not have
access to this IP locally, and as a result will need to create some simulation
models to use on WFH. This does not need to be actual synthesizable HDL - just
some modules that replicate the expected timing and interface of IP you use.

## Pros and Cons

There are some other tradeoffs to consider here. The big one is that Verilator
only supports dual-state simulation - this means that every signal in Verilator
is a 0 or a 1, and there is no X or Z tracking on signals. X-correctness is
something that many students in this course struggle with, and you'll still need
to use VCS to test your design to make sure you have no such issues. Verilator
will treat Xes in your SV as a 0, so don't worry about potential compatibility
issues in your SV.

Additionally, Verilator in the past has had LRM support issues when compared to
VCS. Constrained randomization and UVM, both things that are very important in
the verification industry, only started having basic Verilator support earlier
this year. There are also certain HDL constructs you write that may be flattened
correctly in VCS, but not in Verilator. This is primarily due to Verilator being
a less mature technology when compared to VCS. In this course we optionally offer using
Verilator as a supplement to VCS due to to reasons:

- Faster debug times when dealing with something like Coremark.
- More feasible & faster design space exploration.

Overall Verilator is a very promising simulation tool with many big companies
backing it. Hopefully after `mp_ooo`, you see some of the reasons why that is
the case!

# System Requirements

You will need to install the `verilator` program on your system. Most linux
distributions and Mac OS will have this in their package manager (`homebrew`,
`apt`, etc.). If you would like to view waveforms coming out of Verilator, you
will also need a waveform viewer - popular options are
[surfer](https://surfer-project.org) or
[gtkwave](https://gtkwave.sourceforge.net). Surfer is best downloaed as a binary
off of their website, whereas `gtkwave` can be found in most package mangers.
    
The ECE411 tooling also compiles programs into a `.lst` file that is used to
initialize memory in the testbench. You will need the RISC-V toolchain installed
to support this functionality. EWS uses the 32-bit toolchain, but we also
support a 64-bit toolchain compiled with multilib. If you are attempting WFH,
you should be able to find this package on some package managers, like
`homebrew`, or compile it yourself.

If you are following this guide on EWS, `verilator` and the RISC-V toolchain has
already been installed for you, and is loaded as part of the `ece411.sh` script
you run to gain `vcs` access. You will still need a waveform viewer however if
you wish to work with traces - Verdi does not support the `.fst` files that
Verilator dumps. We are currently working on getting surfer or gtkwave set up,
but for now please use the [VSCode version of
surfer](https://marketplace.visualstudio.com/items?itemName=surfer-project.surfer),
or some other generic waveform viewer of your choice. If you use the VSCode
waveform viewer, be aware that you should try to dump smaller traces when
possible to limit RAM consumption. More on this later.

# Running Your First Simulation

You should be comfortable running simulations with VCS by this point in the
course. Verilator simulations are near-identical. You can run the following
command in `sim`.

```bash
make run_verilator_top_tb PROG={your program}
```

That's it! You should have seen a bunch of terminal output, and some familiar
messages from spike. Inside the `sim` directory, you will still see a
`commit.log` - however, note the lack of a `dump.fsdb`. `fsdb` is a trace format
used by VCS and Verdi - Verilator uses something called `fst`, which is a
different type of compressed trace format, with very similar size overhead to
`fsdb`. For maximum **speed**, we do not dump traces by default. However, we can
dump Verilator traces easily. The following command will dump traces for your
entire program.

```bash
make run_verilator_top_tb PROG={your program} VER_TRACE_START=0
```

If you run this command for some program, you should see a file in `sim` called
`waveform.fst` - you can open this in a waveform viewer, and should be greeted
by a module/signal hierarchy similar to what you would see in a ModelSim or
Vivado simulation trace. I'll leave it to you to figure out how to interact with
this file.

If you are running large programs, your traces can get very large - Coremark,
for example, incurs about 500MB of traces on both VCS and Verilator simulation
platforms. This is fine on EWS (where the storage is free), but if you are
opening traces in the VSCode extension or locally, you may want to generate
smaller traces. You can do this by specifying a "time range" for Verilator to
dump traces. This is done as follows.

```bash
make run_verilator_top_tb PROG={your program} VER_TRACE_START={start time} VER_TRACE_END={end time}
```

With the above command, Verilator will only dump traces in the time range you
specify.

Something odd about our Verilator tooling to note is that you cannot kill the
simulation and retain your simulation results - that is to say, if you `CTRL+C`
while the program is running, you will not receive trace nor the logs. Luckily,
Verilator runs fast enough that you can reach the timeout in a reasonable amount
of time. However, if your CPU is hanging, you may be better off using VCS to
debug, since you can kill the program and still recover some traces.

## Compile Times

Right now for maximum simulation performance, Verilator is compiling your code
with the `-O3` compilation flag. This is a `gcc` flag that optimizes performance
of compiled binaries, but comes at the cost of longer compile times. If you are
using Verilator for debug, this likely is not the behavior you are looking for,
and you can safely delete the `-O3` in the `VER_FLAGS` variable of the
Makefile. This will reduce compile times significantly and (to an extent)
increase runtimes.

# Running Lint

Verilator runs its own linter before every build. You can invoke the linter
without kicking off a build by running the following command in the `sim`
directory.

```bash
make run_verilator_lint
```

Like SpyGlass, Verilator has its own waiver file in `verilator_warn.vlt`. Note
that Verilator tends to have stricter lint than SpyGlass, so you can potentially
pass SpyGlass lint but struggle to pass Verilator lint.

Along a similar vein, since Verilator is a *simulation* framework (not a
synthesis flow), RTL that passes Verilator lint may not necessarily be
synthesizable. Multidriven signals or latches, for example, can sometimes go
uncaught by Verilator. It is in your best interest to run both lint flows
periodically!

# Final Comments

Ventilator is a great tool to use for additional benchmarking and some basic
debug in large program runs, but it can by no means be used as a singular or
exhaustive verification tool. 

If you have any feedback or feature requests, please submit them to Campuswire.
