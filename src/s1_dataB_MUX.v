// Module: s1_dataB_MUX
// Desc:   Select between IMM and dataB from the register file
// Inputs: s1_imm: the immediate
//         s1_dataB: the data from the register file
//         BSel: the signal selecting between the two inputs, which comes from the control unit
// Outputs: s1_ALU_in2: the second input to the ALU
//

`include "const.vh"

module s1_dataB_MUX(
    input [`CPU_DATA_BITS-1: 0] s1_imm,
    input [`CPU_DATA_BITS-1: 0] s1_dataB,
    input BSel,
    output [`CPU_DATA_BITS-1: 0] s1_ALU_in2
);

    assign s1_ALU_in2 = (BSel == 1'b1) ? s1_imm : s1_dataB;

endmodule