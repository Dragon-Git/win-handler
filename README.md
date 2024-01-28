Window Handler Examples release 0.1 (SNUG Austin, 23 Sep 2014)
---

## INSTRUCTIONS:

A common verification challenge is performing transaction level checks during windows of time when signal values are hard to predict. A testbench may generate predicted values too early or too late relative to the design under test, although the design behavior is nevertheless valid. This generates many false errors, increasing the effort to debug regressions and enhance testbench code. While many solutions exist for solving this problem, most have various deficiencies, typically adding leniency in the checking and increasing code complexity.

This paper proposes a generic window handler as a solution to overcome these issues in many practical situations. The window handler encapsulates timing characteristics of the hard-to-model behavior, reducing complexity of the testbench code without sacrificing rigor in transaction checks. When applied to an example design, this technique eliminated many false errors from simulations, allowing more time to find real bugs and quickly achieving error-free regressions.

- Build the example testbench and DUT in VCS with the following command
  (additional options as desired, such as -debug_all for gui)
```bash
    vcs -sverilog example_TB.sv
```

- Execute example with the following command (optional -gui)
```bash
    ./simv
```

- To use window handler in a testbench, `include the following:
```systemverilog
    `include "win_handler_macros.svh"
    `include "win_handler_base.sv"
```

- Window Handler base class requires `WIN_MAX_DATA_WIDTH to be defined to
  accomodate maximum data size for transaction fields

- For additional guidance, refer to published paper or example_TB.sv


Feel free to send comments or suggestions:
jeff.vance@verilab.com




