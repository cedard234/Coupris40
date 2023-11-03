// Module: s0_REG (The 32 registers)
// Desc:   The 32 registers for the processor
// Inputs: clk: the clock
//         reset: the reset signal
//         RegWEn: the register write enable signal
//         s0_AddrA: the address of the first register to read from
//         s0_AddrB: the address of the second register to read from
//         s3_AddrD: the address of the register to write to
//         s3_DataD: the data to write to the register
// Outputs: s0_DataA: the data from the first register
//          s0_DataB: the data from the second register
//

`include "const.vh"

module s0_REG(
    input clk,
    input reset,
    input RegWEn,
    input [`MEM_TAG_BITS-1: 0] s0_AddrA,
    input [`MEM_TAG_BITS-1: 0] s0_AddrB,
    input [`MEM_TAG_BITS-1: 0] s3_AddrD,
    input [`CPU_DATA_BITS-1: 0] s3_DataD,
    output [`CPU_DATA_BITS-1: 0] s0_DataA,
    output [`CPU_DATA_BITS-1: 0] s0_DataB
)

    reg [`CPU_DATA_BITS-1: 0] registers [`CPU_INST_BITS: 1];

    always@(posedge clk) begin
        if (reset) begin
            integer i;
            for (i = 1; i <= `CPU_INST_BITS; i = i + 1) begin
                registers[i] <= `CPU_DATA_BITS'h0;
            end
        end
        else begin
            if (RegWEn) begin
                if (s3_AddrD > 0) begin
                    registers[s3_AddrD] <= s3_DataD;
                end
            end
        end
    end

    always@(*) begin
        if (s0_AddrA > 0) begin
            s0_DataA = registers[s0_AddrA];
        end
        else begin
            s0_DataA = `CPU_DATA_BITS'h0;
        end

        if (s0_AddrB > 0) begin
            s0_DataB = registers[s0_AddrB];
        end
        else begin
            s0_DataB = `CPU_DATA_BITS'h0;
        end
    end
endmodule