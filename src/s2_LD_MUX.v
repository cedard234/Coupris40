// Module: s2_LD_MUX
// Desc:   The Multiplexer to decide whether to load a byte, halfword, or word
// Inputs: s2_dataR: the data from the Data Memory
//         LdU : the control signal to decide whether to load a byte, an unsigned byte, a halfword, an unsigned halfword, or a word
// Outputs: s2_dataR_ld: the processed output

`include "const.vh"
`include "Opcode.vh"

module s2_LD_MUX(
    input [`CPU_DATA_BITS-1: 0] s2_dataR,
    input [3:0] LdU,
    output reg [`CPU_DATA_BITS-1: 0] s2_dataR_ld
);

    always@(*) begin
        case(LdU)
            `FNC_LB:           s2_dataR_ld = {{24{s2_dataR[7]}}, s2_dataR[7:0]};
            `FNC_LBU:  s2_dataR_ld = {{24{1'b0}}, s2_dataR[7:0]};
            `FNC_LH:       s2_dataR_ld = {{16{s2_dataR[15]}}, s2_dataR[15:0]};
            `FNC_LHU:  s2_dataR_ld = {{16{1'b0}}, s2_dataR[15:0]};
            `FNC_LW:           s2_dataR_ld = s2_dataR;
            default:            s2_dataR_ld = `CPU_DATA_BITS'b0;
        endcase
    end

endmodule