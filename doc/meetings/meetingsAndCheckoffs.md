# Meeting 5 Nov 2023
## Todos
No Forwarding Datapath:
| Components | mux(2/3) | shifter(4) | PC(reset) | reg(reset) | imm. gen | branch. comps | ld | ALU | Control(Reset) | Pipeline Reg |
| ---------- | -------- | ---------- | --------- | ---------- | -------- | ------------- | -- | --- | -------------- | ------------ |
| rtl        | Done     | Done       | Done      | Done       | Done     | Done          | Done | Done | Done           | Done         |
| testbench  | N        | N          | N         | N          | N        | N             | N    | N    | N              | Done         |
| assertion  | N/A      | N/A        | Done      | N          | N/A      | N/A           | N/A  | N/A  | N              | N/A          |
| past tb    |          |            |           |            |          |               |      |      |                |              |

# Check off with Ken 27 Oct 2023
- [x] Redraw the pipeline diagram
    -   [x] PC should be in line with IMEM, since IMEM is synchronous.
    -   [x] It is better to place IMM GEN before register to cut critical path length.
    -   [x] DMEM should be in line with other registers.

# Notes 24 Oct 2023

## Objective
Checkpoint1: Checkoff by next Monday.

## Todos
-   Common
    -   To discuss where to slice the pipeline diagram.
    -   Draw the 
    -   ALU(Verilog)/ALU testbench design
    -   Python program for ALU test vector generation

## Progress
-   Di
    -   pipeline diagram(halfway through); see [/doc/pipelineDiagram](/doc/pipelineDiagram/pipelineDiagram.png)
    ![](/doc/pipelineDiagram/pipelineDiagram.png)