
# ECE 411: MP Out-Of-Order ADVANCED_FEATURES

## Advanced Feature Rules:
- You need to select **at least** 3 different categories of advanced
  feature points before you can double-up in any category.
  - The miscellaneous category does **not** count toward the 3
    category requirement.
    - Furthermore, you cannot receive points from the miscellaneous
      category unless you have your 3 categories already implemented.
  - Only advanced features fully implemented and integrated into your
    final competition submission count toward the 3 categories.
- The features in italics are more advanced versions of the base
  features.
  - You cannot earn points for the features in italics without
    implementing the corresponding base feature
- You can receive points for at most 2 different types of predictors
- Branch predictors that implement their tables using flip flops
  instead of SRAMs will only receive half points.
- After you receive your 20 base advanced feature points, you can receive up to 10 points of additional extra credit.
  - These do not need to be integrated, but you will receive a 50% penalty for any non-integrated features. See README for more details.

## All Advanced Features

This list is not exhaustive. If you have a cool idea or find a
relevant research paper you are interested in, make a campuswire post
and course staff will assign a fair amount of points for it. If the
idea you found is especially unique, you might receive extra points
for originality.

### Memory Unit:

- Split LSQ (Loads can be out-of-ordered in between stores) [4]
  - _Loads can be issued OoO w.r.t stores to a different address_ [2]
  - _Non-Committed Store Forwarding on Split LSQ_ [2]
    - _Non-Committed & Misaligned Store Forwarding on Split LSQ_ [1]

### Cache Hierarchy:

- Post-Commit Store Buffer [5]
  - _Write Coalescing in Store Buffer_ [2]
- Non-Blocking Data Cache for a single miss (subsequent hits do not
  stall) [3]
  - _Non-Blocking Data Cache for multiple misses (multiple outstanding
    miss requests)_ [5]

### Prefetchers:

- Next-Line Prefetcher [3]
- Stride Prefetcher [4]
- Stream Buffer Prefetching [4]
- Fetch Directed Instruction Prefetching [5]
- DMP (pointer chasing) [5]

### Branch Predictors (Half Points if structures implemented as FFs instead of SRAM):

- TAGE [8]
- Perceptron [6]
- GShare/GSelect [4]
- Two-Level Predictor (Local History Table & Pattern History Table) [4]
- Enhancements:
  - _BTB (Branch Target Buffer)_ [2 if implemented alongside a
    predictor]
  - _Tournament/Hybrid/Combined_ [2]
  - _Overriding branch prediction_ [2 if also using TAGE/Perceptron]

### RISC-V Extensions:

- C (Compressed Instructions) Extension [5]
  - _If also superscalar_ [3]
- F (Floating Point) Extension (Synopsys IP) [8]

### Advanced Microarchitectural Optimizations:

- Superscalar (2-way) [12]
  - Superscalar (N-Way) [3]
- Early Branch Recovery (requires checkpointing & branch stack masking) [12]
- Fire and Forget [16]

### Performance Analysis, Visualization, & Verification:

- Design Space Exploration Scripts [4]
- Non-Synthesizable Processor Model [4]
- Benchmark Analysis [4]
- Processor Visualization Tool [4]
- Full-System UVM Verification Environment [4]
- Full-System Cocotb Verification Environment [4]

### Misc:

- 1.0 IPC Write Throughput Cache [2]
- Age Ordered Issue Scheduling [2]
- Banked Cache [2]
- Parametrized Sets & Ways Cache (incl PLRU) [2]
- Return Address Stack [2]

## Advanced Features that Especially Benefit from Early Consideration

### Superscalar

Out-of-order processors exploit instruction level parallelism for
better performance. Why not exploit it some more?

A superscalar processor is a processor that can handle >1 instructions
in the same clock cycle at every stage: Fetch, Decode, Dispatch,
Issue, Writeback, Commit, etc. The *superscalar width* of a processor
is the minimum number of instructions each stage can handle in the
same clock cycle.

For example, a processor that fetches only 1 instruction at a time is
not superscalar, even if the rest of the processor can handle more
than one instruction simultaneously. A processor with a minimum width
of 2 would be called a 2-way superscalar processor. A
parametrized-width processor would be called an N-way superscalar
processor.

Without stalls, a 2-way superscalar processor should be able to
achieve an IPC of 2.0 for highly parallel programs.

If you are interested in this feature, you should plan ahead when
writing your code. Either make your processor superscalar from the
start, or write your code clearly so you can easily extend it later.

### Early Branch Recovery

Your out-of-order processors have a deep pipeline. It can take dozens
of clock cycles before a branch makes its way to the head of the
ROB. Therefore, mispredicted branches can have a large impact on
performance. Think about how in mp_pipeline you have to flush several
stages whenever you mispredict a branch. This problem becomes worse as
you add more stages, and out-of-order processors can be hurt even more
significantly.

When you mispredict a branch, there may be several instructions
elsewhere in your pipeline that should not be committed. In
mp_pipeline, we could recover in a relatively straightforward manner
by squashing branches at pipeline stages earlier than the branch. This
is not so straightforward in an out-of-order processor. For example,
it can be tricky to keep track of which instructions are younger than
others. If you directly implement the processor described in lecture,
the only structure that maintains program order is the
ROB. Consequently, the simplest way to handle mispredicts is to flush
everything when committing a mispredicted branch (and no
earlier). Depending on exactly when the branch commits, this can take
a long time, resulting in a very large mispredict penalty.

Early branch recovery solves this by adding logic to your pipeline to
enable branches to flush only instructions younger than themselves
before commit. In the most ideal case, as soon as the branch is
resolved, you can squash all of the incorrectly fetched instructions.

If you are interested in this feature, you should consider from the
beginning how to tag instructions in your processor with the metadata
necessary for squashing logic. This can be especially tricky with
explicit register renaming.


## A Few Words of Warning

It is critical to consider which advanced features pair well with one
another. Depending on where the bottlenecks are in your system, some
features may not help performance at all. Others may dramatically
improve performance. Some features may be useless until a different
feature is implemented alongside them. To this end, we strongly
recommend adding performance counters/hooks all over your processor so
you can identify where to improve performance. In addition, you should
discuss your advanced feature ideas with your mentor TA so you can
pick some with good synergies.
