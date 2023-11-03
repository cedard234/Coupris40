// Module: s1_dataA_MUX
// Desc:   Select between PC and dataA from the register file
// Inputs: s1_pc: the program counter
//         s1_dataA: the data from the register file
//         ASel: the signal selecting between the two inputs, which comes from the control unit
// Outputs: s1_ALU_in1: the first input to the ALU
//

`include "const.vh"

module(
    input [`CPU_INST_BITS-1: 0] s1_pc,
    input [`CPU_DATA_BITS-1: 0] s1_dataA,
    input ASel,
    output [`CPU_DATA_BITS-1: 0] s1_ALU_in1
)

    assign s1_ALU_in1 = (ASel == 1'b1) ? s1_pc : s1_dataA;
    
endmodule