module sram_combined(
  clk,we,wmask,addr,din,dout
);

  // These parameters should NOT be set to
  // anything other than their defaults.
  parameter DATA_WIDTH = 32*4 ;
  parameter ADDR_WIDTH = 8 ;
  parameter WMASK_WIDTH = 4*4 ;
  parameter RAM_DEPTH = 1 << ADDR_WIDTH;

  input  clk; // clock
  input  we; // write enable
  input [WMASK_WIDTH-1:0] wmask; // write mask
  input [ADDR_WIDTH-1:0]  addr; // address
  input [DATA_WIDTH-1:0]  din; // data in
  output reg [DATA_WIDTH-1:0] dout; // data out
  
  sram22_256x32m4w8 sram0(
    .clk(clk),
    .we(we),
    .wmask(wmask[3:0]),
    .addr(addr),
    .din(din[31:0]),
    .dout(dout[31:0])
   );

  sram22_256x32m4w8 sram1(
    .clk(clk),
    .we(we),
    .wmask(wmask[7:4]),
    .addr(addr),
    .din(din[63:32]),
    .dout(dout[63:32])
   );

    sram22_256x32m4w8 sram2(
    .clk(clk),
    .we(we),
    .wmask(wmask[11:8]),
    .addr(addr),
    .din(din[95:64]),
    .dout(dout[95:64])
   );

  sram22_256x32m4w8 sram3(
    .clk(clk),
    .we(we),
    .wmask(wmask[15:12]),
    .addr(addr),
    .din(din[127:96]),
    .dout(dout[127:96])
    );

endmodule