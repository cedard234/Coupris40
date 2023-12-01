`include "util.vh"
`include "const.vh"

module cache #
(
  parameter LINES = 64,
  parameter CPU_WIDTH = `CPU_INST_BITS,
  parameter WORD_ADDR_BITS = `CPU_ADDR_BITS-`ceilLog2(`CPU_INST_BITS/8)
)
(
  input clk,
  input reset,

  input                       cpu_req_valid,
  output                      cpu_req_ready,
  input [WORD_ADDR_BITS-1:0]  cpu_req_addr,
  input [CPU_WIDTH-1:0]       cpu_req_data,
  input [3:0]                 cpu_req_write,

  output                      cpu_resp_valid,
  output [CPU_WIDTH-1:0]      cpu_resp_data,

  output                      mem_req_valid,
  input                       mem_req_ready,
  output [WORD_ADDR_BITS-1:`ceilLog2(`MEM_DATA_BITS/CPU_WIDTH)] mem_req_addr,
  output                           mem_req_rw,
  output                           mem_req_data_valid,
  input                            mem_req_data_ready,
  output [`MEM_DATA_BITS-1:0]      mem_req_data_bits,
  // byte level masking
  output [(`MEM_DATA_BITS/8)-1:0]  mem_req_data_mask,

  input                       mem_resp_valid,
  input [`MEM_DATA_BITS-1:0]  mem_resp_data
);

  two_way_associative_cache c(
    .clk(clk),
    .reset(reset),

    .cpu_req_valid(cpu_req_valid),
    .cpu_req_ready(cpu_req_ready),
    .cpu_req_addr(cpu_req_addr),
    .cpu_req_data(cpu_req_data),
    .cpu_req_write(cpu_req_write),

    .cpu_resp_valid(cpu_resp_valid),
    .cpu_resp_data(cpu_resp_data),

    .mem_req_valid(mem_req_valid),
    .mem_req_ready(mem_req_ready),
    .mem_req_addr(mem_req_addr),
    .mem_req_rw(mem_req_rw),
    .mem_req_data_valid(mem_req_data_valid),
    .mem_req_data_ready(mem_req_data_ready),
    .mem_req_data_bits(mem_req_data_bits),
    .mem_req_data_mask(mem_req_data_mask),

    .mem_resp_valid(mem_resp_valid),
    .mem_resp_data(mem_resp_data)
  );

endmodule