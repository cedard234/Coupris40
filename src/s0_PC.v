// Module: s0_PC (Program Counter)
// Desc:   The program counter for the processor
// Inputs: clk: the clock
//         reset: the reset signal
//         s0_pc_next: the next value of the program counter, or the output from s0_PC_MUX
// Outputs: s0_pc: the current value of the program counter
//

`include "Opcode.vh"
`include "ALUop.vh"
`include "const.vh"

module s0_PC(
    input clk,
    input reset,
    input [`CPU_DATA_BITS-1: 0] s0_pc_next,
    output reg [`CPU_DATA_BITS-1: 0] s0_pc
);

    always@(posedge clk) begin
        if (reset) begin
            s0_pc <= `PC_RESET; // Reset to 0x00002000
        end
        else begin
            s0_pc <= s0_pc_next;
        end
    end

endmodule

// Property: when reset is asserted, the PC is 0x00002000
Property PC_reset;
    @(posedge clk)
    (reset) |-> (s0_pc == `PC_RESET);
endproperty
PC_is_set_to_PC_RESET_when_reset_is_asserted: assert property (PC_reset);