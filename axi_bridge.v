module axi_bridge(
    output         aclk,
    output         aresetn,
    // read request channel
    output  [3:0]  arid,        // inst:0 data:1
    output  [31:0] araddr,      
    output  [7:0]  arlen,       // zero
    output  [2:0]  arsize,      
    output  [1:0]  arburst,     // 2'b01
    output  [1:0]  arlock,      // zero
    output  [3:0]  arcache,     // zero
    output  [2:0]  arprot,      // zero
    output         arvalid,
    input          arready,
    // read response channel
    input   [3:0]  rid,
    input   [31:0] rdata,  
    input   [1:0]  rresp,       // ignore
    input          rlast,       // ignore
    input          rvalid,      
    output         rready,
    // write request channel
    output  [3:0]  awid,        // 4'b1
    output  [31:0] awaddr,      
    output  [7:0]  awlen,       // zero
    output  [2:0]  awsize,
    output  [1:0]  awburst,     // 2'b01
    output  [1:0]  awlock,      // zero
    output  [3:0]  awcache,     // zero
    output  [2:0]  awprot,      // zero
    output         awvalid,
    input          awready,
    // write response channel
    output  [3:0]  wid,         // 4'b1
    output  [31:0] wdata,
    output  [3:0]  wstrb,
    output         wlast,       // 1
    output         wvalid,
    input          wready,
    input   [3:0]  bid,         // ignore
    input   [1:0]  bresp,       // ignore
    input          bvalid,
    output         bready,
    // inst sram interface
    input         inst_sram_req,
    input  [3:0]  inst_sram_wstrb,
    input  [31:0] inst_sram_addr,
    input  [31:0] inst_sram_wdata,
    output [31:0] inst_sram_rdata,
    input  [1:0]  inst_sram_size,
    output        inst_sram_addr_ok,
    output        inst_sram_data_ok,
    input         inst_sram_wr,
    // data sram interface
    input         data_sram_req,
    input  [3:0]  data_sram_wstrb,
    input  [31:0] data_sram_addr,
    input  [31:0] data_sram_wdata,
    output [31:0] data_sram_rdata,
    input  [1:0]  data_sram_size,
    output        data_sram_addr_ok,
    output        data_sram_data_ok,
    input         data_sram_wr
);

// AXI Fixed signals;
wire reset;
assign reset    = ~aresetn;
assign arlen    = 8'b0;
assign arburst  = 2'b01;
assign arlock   = 2'b0;
assign arcache  = 4'b0;
assign arprot   = 3'b0;
assign awid     = 4'b1;
assign awlen    = 8'b0;
assign awburst  = 2'b01;
assign awlock   = 2'b0;
assign awcache  = 4'b0;
assign awprot   = 3'b0;
assign wid      = 4'b1;
assign wlast    = 4'b1;


endmodule