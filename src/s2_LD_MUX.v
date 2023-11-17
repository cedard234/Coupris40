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
    input [1: 0] dmemory_address,
    output reg [`CPU_DATA_BITS-1: 0] s2_dataR_ld
);

    always@(*) begin
        case(LdU)
            //  For the case of LB, LBU, LH and LHU, shift according to the memory address
            `FNC_LB: begin
                case (dmemory_address)
                    2'b00: s2_dataR_ld = {{24{s2_dataR[7]}}, s2_dataR[7:0]};
                    2'b01: s2_dataR_ld = {{24{s2_dataR[15]}}, s2_dataR[15:8]};
                    2'b10: s2_dataR_ld = {{24{s2_dataR[23]}}, s2_dataR[23:16]};
                    2'b11: s2_dataR_ld = {{24{s2_dataR[31]}}, s2_dataR[31:24]};
                    default: s2_dataR_ld = {{24{s2_dataR[7]}}, s2_dataR[7:0]};
                endcase
            end
            `FNC_LBU: begin
                case (dmemory_address)
                    2'b00: s2_dataR_ld = {{24{1'b0}}, s2_dataR[7:0]};
                    2'b01: s2_dataR_ld = {{24{1'b0}}, s2_dataR[15:8]};
                    2'b10: s2_dataR_ld = {{24{1'b0}}, s2_dataR[23:16]};
                    2'b11: s2_dataR_ld = {{24{1'b0}}, s2_dataR[31:24]};
                    default: s2_dataR_ld = {{24{1'b0}}, s2_dataR[7:0]};
                endcase
            end
            `FNC_LH: begin
                case(dmemory_address)
                    2'b00: s2_dataR_ld = {{16{s2_dataR[15]}}, s2_dataR[15:0]};
                    2'b01: s2_dataR_ld = {{16{s2_dataR[23]}}, s2_dataR[23:8]};
                    2'b10: s2_dataR_ld = {{16{s2_dataR[31]}}, s2_dataR[31:16]};
                    2'b11: s2_dataR_ld = {16'b0, s2_dataR[31:24]};
                    default: s2_dataR_ld = {{16{s2_dataR[15]}}, s2_dataR[15:0]};
                endcase
            end
            `FNC_LHU: begin
                case(dmemory_address)
                    2'b00: s2_dataR_ld = {{16{1'b0}}, s2_dataR[15:0]};
                    2'b01: s2_dataR_ld = {{16{1'b0}}, s2_dataR[23:8]};
                    2'b10: s2_dataR_ld = {{16{1'b0}}, s2_dataR[31:16]};
                    2'b11: s2_dataR_ld = {16'b0, s2_dataR[31:24]};
                    default: s2_dataR_ld = {{16{1'b0}}, s2_dataR[15:0]};
                endcase
            end 
            `FNC_LW: s2_dataR_ld = s2_dataR;
        endcase
    end

endmodule