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
    // write data channel
    output  [3:0]  wid,         // 4'b1
    output  [31:0] wdata,
    output  [3:0]  wstrb,
    output         wlast,       // 1
    output         wvalid,
    input          wready,
    // write response channel
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

// FSM for read and write
parameter  s0 = 4'b0001;        // wait for read/write 
parameter  s1 = 4'b0010;        // wait for read/write addr handshake
parameter  s2 = 4'b0100;        // wait for read data or write data handshake 
parameter  s3 = 4'b1000;        // write successful

reg [3:0]  read_current_state;
reg [3:0]  read_next_state;
reg [3:0]  write_current_state;
reg [3:0]  write_next_state;

// reset logic
always @(posedge aclk)
begin
    if (reset) 
    begin
        read_current_state <= s0;
        write_current_state <= s0;
    end
    else 
    begin
        read_current_state <= read_next_state;
        write_current_state <= write_next_state;
    end
end

// ATTENTION: we stop sending reading request until we finished all writing request to avoid hazard!!
// read FSM
always @(*)
begin
    if (read_current_state[0])             // s0  wait for read
    begin
        if ((data_sram_req && ~data_sram_wr || inst_sram_req && ~inst_sram_wr) && write_current_state[0])
        begin
            read_next_state <= s1;
        end
        else 
        begin
            read_next_state <= s0;
        end
    end
    else if (read_current_state[1])        // s1 wait for read addr handshake
    begin
        if (arvalid && arready)
        begin
            read_next_state <= s2;
        end
        else
        begin
            read_next_state <= s1;
        end
    end
    else if (read_current_state[2])        // s2 wait for read data
    begin
        if (rready && rvalid)
        begin
            read_next_state <= s0;
        end
        else
        begin
            read_next_state <= s2;
        end
    end
    else 
    begin
        read_next_state <= s0;
    end
end

// write FSM
always @(*)
begin
    if (write_current_state[0])            // s0 wait for write
    begin
        if (data_sram_req && data_sram_wr)
        begin
            write_next_state <= s1;
        end
        else
        begin
            write_next_state <= s0;
        end
    end
    else if (write_current_state[1])       // s1 wait for write addr handshake
    begin
        if (awvalid && awready)
        begin
            write_next_state <= s2;
        end
        else
        begin
            write_next_state <= s1;
        end
    end
    else if (write_current_state[2])       // s2 wait for write data handshake
    begin
        if (wvalid && wready)
        begin
            write_next_state <= s3;
        end
        else
        begin
            write_next_state <= s2;
        end
    end
    else if (write_current_state[3])       // s3 wait for write response
    begin
        if (bvalid && bready)
        begin
            write_next_state <= s0;
        end
        else
        begin
            write_next_state <= s3;
        end
    end
    else 
    begin
        write_next_state <= s0;
    end
end

// ATTENTION : we allow reading data_sram first, then inst_sram
reg reading_inst_sram;
reg reading_data_sram;

always @(posedge aclk)
begin
    if (reset)
    begin
        reading_inst_sram <= 1'b0;
    end
    else if (read_current_state[0] && inst_sram_req && ~inst_sram_wr && write_current_state[0] && ~data_sram_req)
    begin
        reading_inst_sram <= 1'b1;
    end
    else if (read_current_state[2] && rready && rvalid)  // finished reading
    begin
        reading_inst_sram <= 1'b0;
    end
    else
    begin
        reading_inst_sram <= reading_inst_sram;
    end
end

always @(posedge aclk)
begin
    if (reset)
    begin
        reading_data_sram <= 1'b0;
    end
    else if (read_current_state[0] && data_sram_req && ~data_sram_wr && write_current_state[0])
    begin
        reading_data_sram <= 1'b1;
    end
    else if (read_current_state[2] && rready && rvalid)  // finished reading
    begin
        reading_data_sram <= 1'b0;
    end
    else
    begin
        reading_data_sram <= reading_data_sram;
    end
end

// control two handshakes for data write
reg  addr_handshake;
reg  data_handshake;
always @(posedge aclk)
begin
    if (reset)
    begin
        addr_handshake <= 1'b0;
        data_handshake <= 1'b0;
    end
    else if (awready)
    begin
        addr_handshake <= 1'b1;
        data_handshake <= data_handshake;
    end
    else if (wready && addr_handshake)
    begin
        addr_handshake <= addr_handshake;
        data_handshake <= 1'b1;
    end
    else if (data_handshake)
    begin
        addr_handshake <= 1'b0;
        data_handshake <= 1'b0;
    end
    else 
    begin
        addr_handshake <= addr_handshake;
        data_handshake <= data_handshake;
    end
end

// interact signals
// interact with sram
// interact with inst_sram
assign inst_sram_addr_ok = arready && reading_inst_sram;
assign inst_sram_data_ok = rvalid && reading_inst_sram;
assign inst_sram_rdata   = rdata;
// interact with data_sram
// ATTENTION: data_sram has both read and write, and write_addr ok needs two handshakes(awready and wready)
assign data_sram_addr_ok = arready && reading_data_sram || data_handshake;
assign data_sram_data_ok = rvalid && reading_data_sram || bvalid;
assign data_sram_rdata   = rdata;

// interact with axi
// read request controlled by s1
assign arid    = read_current_state[1] && reading_data_sram;
assign araddr  = ~read_current_state[1] ? 32'b0 :
                reading_data_sram ? data_sram_addr : inst_sram_addr;
assign arsize  = ~read_current_state[1] ? 3'b0 :
                reading_data_sram ? {1'b0,data_sram_size} :{1'b0,inst_sram_size};
assign arvalid = read_current_state[1];

// read response controlled by s2
assign rready  = read_current_state[2];

// write request controlled by s1
assign awaddr  = write_current_state[1] ? data_sram_addr : 32'b0;
assign awsize  = write_current_state[1] ? {1'b0,data_sram_size} : 3'b0;
assign awvalid = write_current_state[1];

// write data controlled by s2
assign wdata   = write_current_state[2] ? data_sram_wdata : 32'b0;
assign wstrb   = write_current_state[2] ? data_sram_wstrb : 4'b0;
assign wvalid  = write_current_state[2];

// write response controlled by s3
assign bready  = write_current_state[3];

endmodule
