`include "util.vh"
`include "const.vh"

module two_way_associative_cache #
(
  parameter LINES = 64,
  parameter CPU_WIDTH = `CPU_INST_BITS,
  parameter WORD_ADDR_BITS = `CPU_ADDR_BITS-`ceilLog2(`CPU_INST_BITS/8)
)
(
  input clk,
  input reset,

  input                       cpu_req_valid,
  output reg                      cpu_req_ready,
  input [WORD_ADDR_BITS-1:0]  cpu_req_addr,
  input [CPU_WIDTH-1:0]       cpu_req_data,
  input [3:0]                 cpu_req_write,

  output reg                     cpu_resp_valid,
  output reg [CPU_WIDTH-1:0]      cpu_resp_data,

  output                      mem_req_valid,
  input                       mem_req_ready,
  output reg [WORD_ADDR_BITS-1:`ceilLog2(`MEM_DATA_BITS/CPU_WIDTH)] mem_req_addr,
  output reg                          mem_req_rw,
  output reg                          mem_req_data_valid,
  input                            mem_req_data_ready,
  output reg [`MEM_DATA_BITS-1:0]      mem_req_data_bits,
  // byte level masking
  output reg [(`MEM_DATA_BITS/8)-1:0]  mem_req_data_mask,

  input                       mem_resp_valid,
  input [`MEM_DATA_BITS-1:0]  mem_resp_data
);

  // States
  localparam IDLE = 0; 
  localparam READ = 1;
  localparam READ_MEM = 2;
  localparam WRITE = 3;
  localparam WRITE_MEM = 4;
  localparam WRITE_THRU = 5;
  localparam WRITE_STALL = 6;

  // localparam READ_MEM1 = 2
  // localparam READ_MEM2 = 3
  // localparam READ_MEM3 = 4

  // Define internal signals
  reg [32:0] state, next_state; // FSM

  reg [3:0] offset; // TIO
  reg [5:0] index;
  reg [19:0] tag;
  reg [3:0] offset_c; 
  reg [5:0] index_c;
  reg [19:0] tag_c;
  reg [WORD_ADDR_BITS-1:0] cpu_req_addr_store; // Need to store the addr when entering read

  wire cache_hit, tag_match, valid; // cache status

  wire way0_metadata_write_en, way1_metadata_write_en; // SRAM input/outputs
  reg [31:0] way0_metadata_tag_read, way0_metadata_tag_write;
  reg way0_wen, way1_wen;
  reg [15:0] way0_wmask, way1_wmask;
  reg [127:0] way0_sram_data_in, way0_sram_data_out, way1_sram_data_in, way1_sram_data_outs;
  reg [7:0] way0_sram_addr, way1_sram_addr;

  reg [3:0] mem_read_cycle_check;

  // Partition addresses to T/I/O
  assign {tag, index, offset} = cpu_req_addr_store;
  assign {tag_c, index_c, offset_c} = cpu_req_addr;

  // Sequetial Logic
  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      mem_read_cycle_check <= 4'b0000;
      cpu_req_addr_store <= 0;
    end else begin
      if (state == IDLE) begin
        cpu_req_addr_store <= cpu_req_addr;
        mem_read_cycle_check <= 4'b0000;
      end 
      
      else if (state == READ_MEM || state == WRITE_THRU) begin
        mem_read_cycle_check <= mem_read_cycle_check + 1'b1;
      end

      // else if (state == WRITE_THRU) begin
      //   mem_write_cycle_check  <= mem_write_cycle_check + 1'b1;
      // end

      else if (state == READ_MEM) begin
        mem_read_cycle_check <= mem_read_cycle_check + 1'b1;
      end
      state <= next_state;

      if (state == READ && cache_hit == 1'b1) begin
        cpu_resp_data <= way0_sram_data_out[offset[1:0]*32 +: 32]; // Read the correct block
      // cpu_resp_data <= way0_sram_data_out[32 : offset[1:0]*32];
      end
    end

  end

  // Define state transistions
  always @(*) begin
    case(state) 
      IDLE: begin
        if (cpu_req_valid) begin
          if (cpu_req_write == 4'b0000) begin
            next_state = READ;
          end else
            next_state = WRITE;
        end else begin
          next_state = IDLE;
        end
      end

      READ: begin
        case(cache_hit)
          1'b1: next_state = IDLE;
          1'b0: next_state = READ_MEM;
          default: next_state = READ_MEM;
        endcase
      end

      READ_MEM: begin
        case (mem_read_cycle_check == 5)
          1'b1: next_state = READ;
          1'b0: next_state = READ_MEM;
          default: next_state = READ_MEM;
        endcase
      end


      // Write
      WRITE: begin
        case (mem_req_ready) 
          1'b1: next_state = WRITE_MEM;
          1'b0: next_state = WRITE;
          default: next_state = WRITE;
        endcase
      end

      WRITE_MEM: begin
        case (mem_req_data_ready) 
          1'b1: next_state = WRITE_THRU;
          1'b0: next_state = WRITE_MEM;
          default: next_state = WRITE_MEM;
        endcase
      end

      // WRITE_MEM: begin
      //   case (mem_req_data_ready) 
      //     1'b1: next_state = WRITE_STALL;
      //     1'b0: next_state = WRITE_MEM;
      //     default: next_state = WRITE_MEM;
      //   endcase
      // end

      WRITE_THRU: begin
        case (mem_read_cycle_check == 5) 
          1'b1: next_state = WRITE_STALL;
          1'b0: next_state = WRITE_THRU;
          default: next_state = WRITE_THRU;
        endcase
      end

      WRITE_STALL: begin
        next_state = IDLE;
      end

      // WRITE: begin
      //    next_state <= IDLE;
      // end

    endcase
  end

  wire mem_read_in_range;
  assign mem_read_in_range = (mem_read_cycle_check > 0) && (mem_read_cycle_check < 5);
  assign way0_metadata_write_en = (way0_wen) && (mem_read_cycle_check == 2'b01); 
  assign tag_match = (tag == way0_metadata_tag_read[19:0]) ? 1'b1 : 1'b0;
  assign valid = 1'b1;
  assign cache_hit = (state == READ) && (tag_match) && (valid);

  
  // Define Output Logic for each state
  assign cpu_req_ready = (state == IDLE || state == WRITE_STALL) ? 1'b1 : 1'b0;
  assign cpu_resp_valid = (state == READ && cache_hit == 1'b1) ? 1'b1 : 1'b0;

  assign way0_metadata_tag_write = {12'b0, tag};
  assign mem_req_valid = ((state == READ_MEM) || (state == WRITE) || (state == WRITE_THRU)) ? 1'b1 : 1'b0;
  assign mem_req_addr[29:2] = (cpu_req_addr_store >> 2) + mem_read_cycle_check; 

  assign mem_req_rw = ((state == WRITE) || (state == WRITE_MEM) || (state == WRITE_STALL)) ? 1'b1 : 1'b0;
  assign mem_req_data_valid = (state == WRITE_MEM) ? 1'b1 : 1'b0;

  assign mem_req_data_mask = (state == WRITE_MEM) ? (cpu_req_write << (cpu_req_addr_store[1:0]*4)) : 16'h0000;
  always @(*) begin
    mem_req_data_bits = 0;
      case (offset[1:0])
        2'b00: mem_req_data_bits[31:0] = cpu_req_data;
        2'b01: mem_req_data_bits[63:32] = cpu_req_data;
        2'b10: mem_req_data_bits[95:64] = cpu_req_data;
        2'b11: mem_req_data_bits[127:96] = cpu_req_data;
      endcase
    
    // enable all write mask when writing
    way0_wmask = 16'h0000;
    way0_wen = 1'b0;
    if (state == READ_MEM && mem_read_in_range) begin
        way0_wmask = 16'hFFFF;
        way0_wen = 1'b1;
    end 


    else if (state == WRITE_THRU && mem_read_in_range) begin
        way0_wmask = 16'hFFFF;
        way0_wen = 1'b1;            
    end 

    // Define way0_sram_addr
    if (state == IDLE) begin
        way0_sram_addr = {index_c, offset_c[3:2]};
    // end else if (state == READ) begin
    end else if (next_state == READ) begin // Need to offset by a cycle
        way0_sram_addr = {index, offset[3:2]};
    end 
    else if (state == READ_MEM || state == WRITE_THRU) begin
        way0_sram_addr = {index, 2'b00} + mem_read_cycle_check - 1;
    end 
    // else if (state == READ_MEM) begin
    //     way0_sram_addr = {index, 2'b00} + mem_read_cycle_check - 1;
    // end 
    else begin
        way0_sram_addr = {index, offset[3:2]};
    end

    // Generate sram input
    if ((state == READ_MEM) || (state == WRITE_THRU)) begin
      way0_sram_data_in = mem_resp_data;
    end else begin
      way0_sram_data_in = 0;
    end
  end


  // Setup SRAMs

  sram22_64x32m4w32 metadata_way0(
    .clk(clk),
    .we(way0_metadata_write_en),
    .wmask(1'b1),
    .addr(way0_sram_addr[7:2]),
    .din(way0_metadata_tag_write),
    .dout(way0_metadata_tag_read)
  ); 


  sram_combined sram_way0(
    .clk(clk),
    .we(way0_wen),
    .wmask(way0_wmask),
    .addr(way0_sram_addr),
    .din(way0_sram_data_in),
    .dout(way0_sram_data_out)
  );


endmodule