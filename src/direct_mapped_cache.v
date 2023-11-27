`include "util.vh"
`include "const.vh"

module direct_mapped_cache #
(
  parameter LINES = 64,
  parameter CPU_WIDTH = `CPU_INST_BITS,
  parameter WORD_ADDR_BITS = `CPU_ADDR_BITS-`ceilLog2(`CPU_INST_BITS/8) // 32-2 = 30
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
  output [WORD_ADDR_BITS-1:`ceilLog2(`MEM_DATA_BITS/CPU_WIDTH)] mem_req_addr, // 29: 2, why? We are reading 4 words at a time
  output                           mem_req_rw,
  output                           mem_req_data_valid,
  input                            mem_req_data_ready,
  output [`MEM_DATA_BITS-1:0]      mem_req_data_bits,
  // byte level masking
  output [(`MEM_DATA_BITS/8)-1:0]  mem_req_data_mask,

  input                       mem_resp_valid,
  input [`MEM_DATA_BITS-1:0]  mem_resp_data
);

    localparam IDLE = 0, READ = 1, READ_MEM = 2, WRITE = 3;
    reg [1:0] state, next_state;
    wire [5:0] offset, offset_old;
    wire [5:0] index, index_old;
    wire [19:0] tag, tag_old;
    wire [3:0] cache_write_enable;
    wire [20:0] valid_bits_and_tag;
    reg [31:0] cpu_address_archive;
    assign {tag, index, offset} = cpu_req_addr;
    assign {tag_old, index_old, offset_old} = cpu_address_archive; 
    wire READ_hit;
    reg [0:1] READ_MEM_transaction_count;
    wire [7:0] sram_addr;
    wire [31:0] valid_bits_and_tag_new;
    wire WRITE_Done;
    // posedge triggered events
    always@(posedge clk) begin
        if (reset) begin
            state <= idle;
        end else begin
            if (state == IDLE) begin
                cpu_address_archive <= cpu_req_addr;
            end else if (state == READ_MEM) begin
                if (mem_req_ready) begin
                    READ_MEM_transaction_count <= READ_MEM_transaction_count + 1'b1;
                end
            end
            state <= next_state;
        end
    end
    
    // State transition
    always@(*) begin
        case (state) 
            IDLE: begin
                if (cpu_req_valid) begin
                    if (cpu_req_write == 4'b0000) begin
                        next_state = READ;
                    end else begin
                        next_state = WRITE;
                    end
                    end else begin
                        next_state = IDLE;
                    end
            end
            READ: begin
                next_state = READ_hit? IDLE: READ_MEM;
            end
            READ_MEM: begin
                next_state = READ_MEM_transaction_count == 2'b11? READ: READ_MEM;
            end
            WRITE: begin
                next_state = WRITE_Done? IDLE: WRITE;
            end
        endcase
    end

    //What to do in each state
    always@(*) begin
        if (state == IDLE) begin
            sram_addr = {index, offset[5:4]};
        end else if (state == READ_MEM) begin
            sram_addr = {index_old, offset_old[5:4]+READ_MEM_transaction_count};
        end else begin
            sram_addr = {index_old, offset_old[5:4]};
        end

        cache_write_enable = 4'b0000;
        write_mask_for_datasram = 4'b0000;
        if (state == READ_MEM) begin
            write_mask_for_datasram = 4'b1111;
            cache_write_enable = 4'b1111;
        else if (state == WRITE) begin
            cache_write_enable[offset_old[3:2]] = 1'b1;
            write_mask_for_datasram = cpu_req_write; // TODO: this need to be delayed as well
        end
        end
    end
    assign READ_hit = (valid_bits_and_tag[19:0] == tag_old) && (valid_bits_and_tag[20]) && (state == READ);
    assign cpu_req_ready = (state == IDLE) ? 1'b1 : 1'b0;
    assign cpu_resp_valid = (state == READ && READ_hit == 1'b1) ? 1'b1 : 1'b0;
    assign cpu_resp_data = all_read_data_from_datasram[offset[3:0]*8 +: 32];
    assign mem_req_valid = (state == READ_MEM || state == WRITE) ? 1'b1 : 1'b0;
    assign mem_req_addr = cpu_address_archive>>4 + READ_MEM_transaction_count; // Every 4 words
    assign valid_bits_and_tag_new = {11'b0,1'b1,valid_bits_and_tag[19:0]};
    assign WRITE_Done = (state == WRITE) && (mem_req_ready == 1'b1)
    assign mem_req_rw = (state == WRITE) ? 1'b1 : 1'b0;
    assign mem_req_data_valid = (state == WRITE) ? 1'b1 : 1'b0;
    assign mem_req_data_bits[offset_old[3:2]*32 +: 32] = cpu_req_data;
    wire [15:0] write_mask_for_datasram;
    wire [127:0] all_read_data_from_datasram;

    sram22_256x32m4w8 sram0(
    .clk(clk),
    .we(cache_write_enable[0]),
    .wmask(write_mask_for_datasram[3:0]),
    .addr(sram_addr),
    .din(mem_resp_data[31:0]),
    .dout(all_read_data_from_datasram[31:0])
    );

    sram22_256x32m4w8 sram1(
    .clk(clk),
    .we(cache_write_enable[1]),
    .wmask(write_mask_for_datasram[7:4]),
    .addr(sram_addr),
    .din(mem_resp_data[63:32]),
    .dout(all_read_data_from_datasram[63:32])
    );

    sram22_256x32m4w8 sram2(
    .clk(clk),
    .we(cache_write_enable[2]),
    .wmask(write_mask_for_datasram[11:8]),
    .addr(sram_addr),
    .din(mem_resp_data[95:64]),
    .dout(all_read_data_from_datasram[95:64])
    );

    sram22_256x32m4w8 sram3(
    .clk(clk),
    .we(cache_write_enable[3]),
    .wmask(write_mask_for_datasram[15:12]),
    .addr(sram_addr),
    .din(mem_resp_data[127:96]),
    .dout(all_read_data_from_datasram[127:96])
    );

    sram22_64x32m4w32 metadata(
    .clk(clk),
    .we(cache_write_enable),
    .wmask(1'b1),
    .addr(sram_addr),
    .din(valid_bits_and_tag_new),
    .dout(valid_bits_and_tag)
    );

endmodule
