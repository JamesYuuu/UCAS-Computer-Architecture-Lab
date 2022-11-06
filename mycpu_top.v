module mycpu_top(
    input         aclk,
    input         aresetn,
    
    // AXI bridge interface
    // read request channel
    output     [3:0]  arid,     
    output     [31:0] araddr,
    output     [7:0]  arlen,    
    output     [2:0]  arsize,
    output     [1:0]  arburst,  
    output     [1:0]  arlock,   
    output     [3:0]  arcache,  
    output     [2:0]  arprot,   
    output            arvalid,  
    input             arready,  
    // read response channel
    input      [3:0]  rid,
    input      [31:0] rdata,
    input      [1:0]  rresp,    
    input             rlast,    
    input             rvalid,   
    output            rready,   
    // write request channel
    output     [3:0]  awid,
    output     [31:0] awaddr,
    output     [7:0]  awlen,
    output     [2:0]  awsize,
    output     [1:0]  awburst,
    output     [1:0]  awlock,
    output     [3:0]  awcache,
    output     [2:0]  awprot,
    output            awvalid,
    input             awready,
    // write data channel
    output     [3:0]  wid,
    output     [31:0] wdata,
    output     [3:0]  wstrb,
    output            wlast,
    output            wvalid,
    input             wready,
    // write response channel
    input      [3:0]  bid,
    input      [1:0]  bresp,
    input             bvalid,
    output            bready,

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [3:0]  debug_wb_rf_we,
    output [4:0]  debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

    wire         clk;
    wire         resetn;
    assign       clk = aclk;
    assign       resetn = aresetn;

    wire         inst_sram_req;
    wire  [3:0]  inst_sram_wstrb;
    wire  [31:0] inst_sram_addr;
    wire  [31:0] inst_sram_wdata;
    wire  [31:0] inst_sram_rdata;
    wire  [1:0]  inst_sram_size;
    wire         inst_sram_addr_ok;
    wire         inst_sram_data_ok;
    wire         inst_sram_wr;

    wire         data_sram_req;
    wire  [3:0]  data_sram_wstrb;
    wire  [31:0] data_sram_addr;
    wire  [31:0] data_sram_wdata;
    wire  [31:0] data_sram_rdata;
    wire  [1:0]  data_sram_size;
    wire         data_sram_addr_ok;
    wire         data_sram_data_ok;
    wire         data_sram_wr;

axi_bridge axi_bridge(
    .aclk      (aclk    ),
    .aresetn   (aresetn ),
    // read request
    .arid      (arid    ),
    .araddr    (araddr  ),
    .arlen     (arlen   ),
    .arsize    (arsize  ),
    .arburst   (arburst ),
    .arlock    (arlock  ),
    .arcache   (arcache ),
    .arprot    (arprot  ),
    .arvalid   (arvalid ),
    .arready   (arready ),
    // read respond
    .rid       (rid     ),
    .rdata     (rdata   ),
    .rresp     (rresp   ),
    .rvalid    (rvalid  ),
    .rready    (rready  ),
    // write request
    .awid      (awid    ),
    .awaddr    (awaddr  ),
    .awlen     (awlen   ),
    .awsize    (awsize  ),
    .awburst   (awburst ),
    .awlock    (awlock  ),
    .awcache   (awcache ),
    .awprot    (awprot  ),
    .awvalid   (awvalid ),
    .awready   (awready ),
    // write data
    .wid       (wid     ),
    .wdata     (wdata   ),
    .wstrb     (wstrb   ),
    .wlast     (wlast   ),
    .wvalid    (wvalid  ),
    .wready    (wready  ),
    // write respond
    .bid       (bid     ),
    .bresp     (bresp   ),
    .bvalid    (bvalid  ),
    .bready    (bready  ),

    // inst sram interface
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_rdata   (inst_sram_rdata  ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_wr      (inst_sram_wr     ),
    // data sram interface
    .data_sram_req     (data_sram_req    ),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_addr    (data_sram_addr   ),
    .data_sram_wdata   (data_sram_wdata  ),
    .data_sram_rdata   (data_sram_rdata  ),
    .data_sram_size    (data_sram_size   ),
    .data_sram_addr_ok (data_sram_addr_ok),
    .data_sram_data_ok (data_sram_data_ok),
    .data_sram_wr      (data_sram_wr     )
);

mycpu_core mycpu_core(
    .clk               (clk              ),
    .resetn            (resetn           ),
    // inst sram interface
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_rdata   (inst_sram_rdata  ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_wr      (inst_sram_wr     ),
    // data sram interface
    .data_sram_req     (data_sram_req    ),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_addr    (data_sram_addr   ),
    .data_sram_wdata   (data_sram_wdata  ),
    .data_sram_rdata   (data_sram_rdata  ),
    .data_sram_size    (data_sram_size   ),
    .data_sram_addr_ok (data_sram_addr_ok),
    .data_sram_data_ok (data_sram_data_ok),
    .data_sram_wr      (data_sram_wr     ),
    // trace debug interface
    .debug_wb_pc       (debug_wb_pc      ),
    .debug_wb_rf_we    (debug_wb_rf_we   ),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata (debug_wb_rf_wdata)
);

endmodule