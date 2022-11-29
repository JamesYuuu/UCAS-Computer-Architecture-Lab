module IF_stage(
    input           clk,
    input           reset,
    // allowin from ID stage
    input           ds_allowin,
    // branch bus
    input   [33:0]  br_bus,
    // output to ID stage
    output          fs_to_ds_valid,
    output  [65:0]  fs_to_ds_bus,
    // inst sram interface
    output          inst_sram_req,       // if there is a request
    output          inst_sram_wr,        // read or write
    output  [3:0]   inst_sram_wstrb,     // write strobes
    output  [1:0]   inst_sram_size,      // number of bytes  0:1 bytes 1:2bytes 2:4bytes
    output  [31:0]  inst_sram_addr,      // request addr
    output  [31:0]  inst_sram_wdata,     // write data
    input   [31:0]  inst_sram_rdata,     // read data
    input           inst_sram_addr_ok,   // if data and addr has been received
    input           inst_sram_data_ok,   // if data has been written or given back
    // interrupt signal
    input           wb_ex,
    input           wb_ertn,
    input   [31:0]  csr_eentry,
    input   [31:0]  csr_era,

    input           csr_critical_change,
    input           wb_refetch,
    input   [31:0]  refetch_pc,
    // to do address translation
    input   [31:0]      csr_dmw0,
    input   [31:0]      csr_dmw1,
    input   [31:0]      csr_crmd
);

wire refetch_needed;

wire handshake;
reg [4:0] preif_current_state;
reg [4:0] preif_next_state;

parameter s0 = 5'b00001;
parameter s1 = 5'b00010;
parameter s2 = 5'b00100;
parameter s3 = 5'b01000;
parameter s4 = 5'b10000;

// to detech adef
wire adef_detected;

// instruction buffer
reg [31:0] inst_buff;
reg inst_buff_valid;

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        pre_fs_ready_go;

// signals for pc
wire [31:0] seq_pc;
reg [31:0] nextpc_r;
wire [31:0] nextpc;

// signals from branch
wire        br_taken_ori;
wire        br_taken;
wire [31:0] br_target;
assign {br_stall,br_taken_ori,br_target} = br_bus;

assign br_taken = br_taken_ori && ~br_stall;

assign refetch_needed = csr_critical_change;

// signals to output for ID_stage
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {refetch_needed, adef_detected,fs_inst,fs_pc};

// pre-IF stage
assign seq_pc       =   fs_pc + 3'h4;

always @(posedge clk) begin
    nextpc_r <= nextpc;
end

always @(posedge clk)
begin
    if (reset)
    begin
        inst_buff <= 32'b0;
    end
    else if (inst_sram_data_ok)
    begin
        inst_buff <= inst_sram_rdata;
    end
    else 
    begin
        inst_buff <= inst_buff;
    end
end

always @(posedge clk)
begin
    if (reset)
    begin
       inst_buff_valid <= 1'b0;
    end
    else if (ds_allowin)
    begin
        inst_buff_valid <= 1'b0;
    end
    else if (fs_ready_go & inst_sram_data_ok)           // ~ds_allowin
    begin
        inst_buff_valid <= 1'b1;
    end
    else 
    begin
        inst_buff_valid <= inst_buff_valid;
    end
end
    
assign nextpc       =   wb_refetch  ? refetch_pc :
                        wb_ex       ? csr_eentry :
                        wb_ertn     ? csr_era   :
                        preif_current_state[3] | preif_current_state[4] ? nextpc_r :  // br or wb_ex wait for addr_ok
                        br_taken    ? br_target : seq_pc;

assign pre_fs_ready_go = (inst_sram_req && inst_sram_addr_ok);

assign adef_detected = nextpc[1:0] == 2'b00 ? 0 : 1;

// IF stage
assign fs_ready_go     = inst_sram_data_ok | inst_buff_valid;
assign fs_allowin     = !(fs_valid) || fs_ready_go && ds_allowin;
assign fs_to_ds_valid  = fs_valid && fs_ready_go && ~preif_current_state[4];
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= pre_fs_ready_go;
    end
end

// PC update
always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1BFFFFFC;  // make nextpc=0x1C000000;
    end
    else if (preif_current_state[0] & handshake | preif_current_state[3] & handshake) begin
        fs_pc <= nextpc;
    end
    else begin
        fs_pc <= fs_pc;
    end
end


// interface with sram
assign inst_sram_req    = fs_allowin & (preif_current_state[0] | preif_current_state[3]) & ~br_stall;
assign inst_sram_addr   = nextpc;
assign inst_sram_wr     = 1'b0;
assign inst_sram_wstrb  = 4'b0;
assign inst_sram_size   = 2'b10;
assign inst_sram_wdata  = 32'b0;

assign fs_inst          = inst_sram_data_ok ? inst_sram_rdata :
                          inst_buff_valid ? inst_buff : 0;

// add FSM
assign handshake = inst_sram_req & inst_sram_addr_ok;

always @(posedge clk)
begin
    if(reset)
        preif_current_state <= s0;
    else
        preif_current_state <= preif_next_state;
end

always @(*)
begin
    if(preif_current_state[0])                      // s0 wait for handshake
    begin
        if(handshake)
        begin
            if (br_taken | wb_ex | wb_ertn | wb_refetch)            
            begin
                preif_next_state <= s4;
            end
            else
            begin
                preif_next_state <= s1;
            end
        end
        else
        begin
            if(br_taken | wb_ex | wb_ertn | wb_refetch)
            begin
                preif_next_state <= s3;
            end
            else
            begin
                preif_next_state <= s0;
            end
        end
    end
    else if(preif_current_state [1])                // s1 wait for instruction
    begin   
        if((inst_sram_data_ok | inst_buff_valid) & fs_allowin)
        begin
            if (wb_ex | wb_ertn | wb_refetch)
            begin
                preif_next_state <= s3;
            end
            else 
            begin
                preif_next_state <= s0;
            end
        end
        else 
        begin
            if (wb_ex | wb_ertn | wb_refetch)
            begin
                preif_next_state <= s4;
            end
            else
            begin
                preif_next_state <= s1;
            end
        end
    end
    else if(preif_current_state[2])                // s2 wait for instruction br
    begin
        if(inst_sram_data_ok)
        begin
            if (wb_ex | wb_ertn | wb_refetch)
            begin
                preif_next_state <= s3;
            end
            else
            begin
                preif_next_state <= s0;
            end
        end
        else 
        begin
            if (wb_ex | wb_ertn | wb_refetch)
            begin
                preif_next_state <= s4;
            end
            else
            begin
                preif_next_state <= s2;
            end
        end
    end
    else if(preif_current_state[3])                // s3 wait for handshake br
    begin   
        if(handshake)
        begin
            if (wb_ex | wb_ertn | wb_refetch)
            begin
                preif_next_state <= s4;
            end
            else
            begin
                preif_next_state <= s2;
            end
        end
        else
        begin
            preif_next_state <= s3;
        end
    end
    else                                          // s4 drop instruction 
    begin
        if (inst_sram_data_ok) 
        begin
            preif_next_state <= s3;
        end
        else 
        begin
            preif_next_state <= s4;
        end
    end
end
endmodule
