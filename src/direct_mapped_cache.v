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
  output reg [CPU_WIDTH-1:0]      cpu_resp_data,

  output                      mem_req_valid,
  input                       mem_req_ready,
  output [WORD_ADDR_BITS-1:`ceilLog2(`MEM_DATA_BITS/CPU_WIDTH)] mem_req_addr, // 29: 2, why? We are reading 4 words at a time
  output                           mem_req_rw,
  output                           mem_req_data_valid,
  input                            mem_req_data_ready,
  output reg [`MEM_DATA_BITS-1:0]      mem_req_data_bits,
  // byte level masking
  output reg [(`MEM_DATA_BITS/8)-1:0]  mem_req_data_mask,

  input                       mem_resp_valid,
  input [`MEM_DATA_BITS-1:0]  mem_resp_data
);

    localparam IDLE = 0, READ = 1, READ_MEM = 2, WRITE = 3, WRITE_DATA = 4, WRITE_FINISH = 5, WRITE_FROM_MEM = 6;
    reg [2:0] state, next_state;
    reg cpu_req_valid_archive;
    wire [3:0] offset, offset_old;
    wire [5:0] index, index_old;
    wire [19:0] tag, tag_old;
    reg [3:0] cache_write_enable;
    wire [31:0] valid_bits_and_tag;
    reg [31:0] cpu_address_archive;
    reg [3:0] cpu_req_write_archive;
    assign {tag, index, offset} = cpu_req_addr;
    assign {tag_old, index_old, offset_old} = cpu_address_archive; 
    wire READ_hit;
    reg [2:0] READ_MEM_transaction_count;
    reg [7:0] sram_addr;
    wire [31:0] valid_bits_and_tag_new;
    reg [15:0] write_mask_for_datasram;
    wire WRITE_Done;
    wire [127:0] all_read_data_from_datasram;
    reg WRITE_A_WORD;
    // posedge triggered events
    always@(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            cpu_address_archive <= 32'h00000000;
            cpu_req_write_archive <= 4'b0000;
            READ_MEM_transaction_count <= 0;
        end else begin
            if (state == IDLE) begin
                cpu_address_archive <= cpu_req_addr;
                cpu_req_write_archive <= cpu_req_write;
                READ_MEM_transaction_count <= 0;
                
            end else if (state == READ_MEM || state == WRITE_FROM_MEM) begin
                READ_MEM_transaction_count <= READ_MEM_transaction_count + 1'b1;
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
                next_state = READ_hit? IDLE : READ_MEM;
            end
            READ_MEM: begin
                next_state = (READ_MEM_transaction_count == 5)? READ: READ_MEM;
            end
            WRITE: begin
                // next_state = WRITE_Done? IDLE: WRITE;
                next_state = mem_req_ready? WRITE_DATA: WRITE;
            end
            WRITE_DATA: begin
                next_state = mem_req_data_ready ? WRITE_FROM_MEM: WRITE_DATA;
                // next_state = mem_req_data_ready ? WRITE_FINISH: WRITE_DATA;
            end
            WRITE_FROM_MEM: begin
                next_state = (READ_MEM_transaction_count == 5 && mem_resp_valid)? WRITE_FINISH: WRITE_FROM_MEM;
            end
            WRITE_FINISH: begin
                next_state = IDLE;
            end
        endcase
    end

    //What to do in each state
    always@(*) begin
        if (state == IDLE) begin
            sram_addr = {index, offset[3:2]};
        end else
        if (next_state == READ) begin
            sram_addr = {index_old, offset_old[3:2]};
        end else if (state == READ_MEM || state == WRITE_FROM_MEM) begin
            // sram_addr = {index_old, offset_old[3:2]} + READ_MEM_transaction_count-1;
            sram_addr = {index_old, 2'b00} + READ_MEM_transaction_count-1;
        end else begin
            sram_addr = {index_old, offset_old[3:2]};
        end

        cache_write_enable = 4'b0000;
        write_mask_for_datasram = 4'b0000;
        WRITE_A_WORD = 1'b0;
        if (state == READ_MEM && READ_MEM_transaction_count >=1 && READ_MEM_transaction_count <=4) begin
            write_mask_for_datasram = 16'hFFFF;
            cache_write_enable = 4'b1111;
        end
        else if (state == WRITE_FROM_MEM && READ_MEM_transaction_count >= 1 && READ_MEM_transaction_count <= 4) begin
            write_mask_for_datasram = 16'hFFFF;
            cache_write_enable = 4'b1111;            
        end 
        //else if (next_state == WRITE) begin
            // if (cpu_req_write == 4'b1111) begin
            //     cache_write_enable[offset_old[1:0]] = 1'b1;
            //     write_mask_for_datasram = cpu_req_write_archive; // TODO: this need to be delayed as well
            //     WRITE_A_WORD = 1'b1;
            // end
            // end
        end 
    assign READ_hit = (valid_bits_and_tag[19:0] == tag_old) && (valid_bits_and_tag[20]) && (state == READ) ;
    assign cpu_req_ready = (state == IDLE || state == WRITE_FINISH) ? 1'b1 : 1'b0;
    // assign cpu_req_ready = (state == IDLE) ? 1'b1 : 1'b0;
    assign cpu_resp_valid = (state == READ && READ_hit == 1'b1) ? 1'b1 : 1'b0;
    always@(posedge clk) begin
        if (state == READ && READ_hit == 1'b1) begin
            cpu_resp_data <= all_read_data_from_datasram[offset_old[1:0]*32 +: 32];
        end
    end
    // assign cpu_resp_data = all_read_data_from_datasram[offset_old[1:0]*32 +: 32];
    assign mem_req_valid = (state == READ_MEM || state == WRITE || state == WRITE_FROM_MEM || state == WRITE_DATA) ? 1'b1 : 1'b0;
    assign mem_req_addr[29:2] = (cpu_address_archive>>2) + READ_MEM_transaction_count; // Every 4 words
    assign valid_bits_and_tag_new = {11'b0,1'b1,tag_old};
    assign WRITE_Done = (state == WRITE) && (mem_req_ready == 1'b1);
    assign mem_req_rw = (state == WRITE || state == WRITE_DATA || state == WRITE_FINISH) ? 1'b1 : 1'b0;
    assign mem_req_data_valid = (state == WRITE_DATA || state == WRITE) ? 1'b1 : 1'b0;
    always @(*) begin
        mem_req_data_bits = 128'b0;
        case (offset_old[1:0])
            2'b00: mem_req_data_bits[31:0] = cpu_req_data;
            2'b01: mem_req_data_bits[63:32] = cpu_req_data;
            2'b10: mem_req_data_bits[95:64] = cpu_req_data;
            2'b11: mem_req_data_bits[127:96] = cpu_req_data;
        endcase
    end
    // always@(*) begin
    //     // SB, SH and SW according to the write mask given
    //     mem_req_data_mask = 4'b0000;
    //     if (state == WRITE_DATA) begin
    //         if (cpu_req_write[0] + cpu_req_write[1] + cpu_req_write[2] + cpu_req_write[3] == 1) begin
    //             mem_req_data_mask = cpu_req_write << (cpu_address_archive[1:0]*4);
    //         end
    //         else if (cpu_req_write[0] + cpu_req_write[1] + cpu_req_write[2] + cpu_req_write[3] == 2) begin
    //             mem_req_data_mask = cpu_req_write << (cpu_address_archive[2:1]*4);
    //         end
    //         else if (cpu_req_write[0] + cpu_req_write[1] + cpu_req_write[2] + cpu_req_write[3] == 4) begin
    //             mem_req_data_mask = cpu_req_write << (cpu_address_archive[3:2]*4);
    //         end
    //     end
    // end
    // assign mem_req_data_mask = (state == WRITE_DATA) ? write_mask_for_datasram << (cpu_address_archive[1:0]*4) : 4'b0000;

    // assign mem_req_data_mask = (state == WRITE_DATA) ? cpu_req_write << (cpu_address_archive[3:0]) : 4'b0000;
    assign mem_req_data_mask = (state == WRITE_DATA) ? cpu_req_write << (cpu_address_archive[1:0]*4) : 16'h0000;
    
    

    sram22_256x32m4w8 sram0(
    .clk(clk),
    .we(cache_write_enable[0]),
    .wmask(write_mask_for_datasram[3:0]),
    .addr(sram_addr),
    .din((state == READ_MEM || state == WRITE_FROM_MEM) ? mem_resp_data[31:0] : cpu_req_data),
    .dout(all_read_data_from_datasram[31:0])
    );

    sram22_256x32m4w8 sram1(
    .clk(clk),
    .we(cache_write_enable[1]),
    .wmask(write_mask_for_datasram[7:4]),
    .addr(sram_addr),
    .din((state == READ_MEM || state == WRITE_FROM_MEM) ? mem_resp_data[63:32] : cpu_req_data),
    .dout(all_read_data_from_datasram[63:32])
    );

    sram22_256x32m4w8 sram2(
    .clk(clk),
    .we(cache_write_enable[2]),
    .wmask(write_mask_for_datasram[11:8]),
    .addr(sram_addr),
    .din((state == READ_MEM || state == WRITE_FROM_MEM) ? mem_resp_data[95:64] : cpu_req_data),
    .dout(all_read_data_from_datasram[95:64])
    );

    sram22_256x32m4w8 sram3(
    .clk(clk),
    .we(cache_write_enable[3]),
    .wmask(write_mask_for_datasram[15:12]),
    .addr(sram_addr),
    .din((state == READ_MEM || state == WRITE_FROM_MEM) ? mem_resp_data[127:96] : cpu_req_data),
    .dout(all_read_data_from_datasram[127:96])
    );

    sram22_64x32m4w32 metadata(
    .clk(clk),
    .we(((|cache_write_enable) && (READ_MEM_transaction_count == 2'b01))),
    .wmask(1'b1),
    .addr(sram_addr[7:2]),
    .din(valid_bits_and_tag_new),
    .dout(valid_bits_and_tag)
    );

endmodule
