// Module: s2_WB_MUX
// Desc:   The Multiplexer for the Writeback Stage
// Inputs: s2_pc: the program counter
//         s2_ALU: the output from the ALU
//         s2_dataR: the data from the Data Memory
//         WBSel: the signal selecting between the three inputs, which comes from the control unit
// Outputs: s2_wb: the selected output to write back to s0_REG
//

`include "const.vh"

module s2_WB_MUX(
    input [`CPU_INST_BITS-1: 0] s2_pc,
    input [`CPU_DATA_BITS-1: 0] s2_ALU,
    input [`CPU_DATA_BITS-1: 0] s2_dataR,
    input [1:0] WBSel,
    output [`CPU_DATA_BITS-1: 0] s2_wb
);

    assign  
    s2_wb = (WBSel == 2'b00) ? s2_pc 
    : (WBSel == 2'b01) ? s2_ALU 
    : (WBSel == 2'b10) ? s2_dataR 
    : `CPU_DATA_BITS'b0;

endmodule