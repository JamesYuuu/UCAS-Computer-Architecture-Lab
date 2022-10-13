module MEM_stage(
    input   wire            clk,
    input   wire            reset,
    // allowin
    input   wire            ws_allowin,
    output  wire            ms_allowin,
    // input from EXE stage
    input   wire            es_to_ms_valid,
    input   wire [173:0]    es_to_ms_bus,
    // output for WB stage
    output  wire            ms_to_ws_valid,
    output  wire [167:0]    ms_to_ws_bus,
    // data sram interface
    input   wire [31:0]     data_sram_rdata,
    // output ms_valid and ms_to_ds_bus to ID stage
    output                  out_ms_valid,
    // interrupt signal
    input                   wb_ex,
    input                   wb_ertn
);

wire        gr_we;
wire        res_from_mem;
wire [31:0] pc;
wire [4: 0] dest;
wire [31:0] mem_result;
wire [31:0] final_result;

wire [31:0] alu_result;

reg         ms_valid;
wire        ms_ready_go;
reg [173:0] es_to_ms_bus_r;

// add ld op
wire [4:0] ld_op;
wire       inst_ld_b;
wire       inst_ld_bu;
wire       inst_ld_h;
wire       inst_ld_hu;
wire       inst_ld_w; 

assign {inst_ld_b,inst_ld_bu,inst_ld_h,inst_ld_hu,inst_ld_w}=ld_op;

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if(wb_ex || wb_ertn) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end
// deal with input and output
wire [33:0] csr_data;
wire [31:0] rj_value;
wire [31:0] rkd_value;
assign {rj_value,rkd_value,csr_data,ld_op,res_from_mem,gr_we,dest,alu_result,pc}=es_to_ms_bus_r;
assign ms_to_ws_bus={rj_value,rkd_value,csr_data,gr_we,dest,final_result,pc};

//bobbbbbbbbbby add below
wire [31:0] ld_b_result;
wire [31:0] ld_bu_result;
wire [31:0] ld_h_result;
wire [31:0] ld_hu_result;
wire [1:0]  sel;
assign sel = alu_result[1:0];
assign ld_b_result = (sel == 2'b00) ? {{24{data_sram_rdata[7]}}, data_sram_rdata[7:0]} :
                     (sel == 2'b01) ? {{24{data_sram_rdata[15]}}, data_sram_rdata[15:8]} :
                     (sel == 2'b10) ? {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]} :
                     (sel == 2'b11) ? {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]} : 0;
assign ld_bu_result = (sel == 2'b00) ? {{24'b0}, data_sram_rdata[7:0]} :
                      (sel == 2'b01) ? {{24'b0}, data_sram_rdata[15:8]} :
                      (sel == 2'b10) ? {{24'b0}, data_sram_rdata[23:16]} :
                      (sel == 2'b11) ? {{24'b0}, data_sram_rdata[31:24]} : 0;
assign ld_h_result = (sel == 2'b00) ? {{16{data_sram_rdata[15]}}, data_sram_rdata[15:0]} :
                     (sel == 2'b10) ? {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]}: 0;
assign ld_hu_result = (sel == 2'b00) ? {{16'b0}, data_sram_rdata[15:0]} : 
                      (sel == 2'b10) ? {{16'b0}, data_sram_rdata[31:16]} : 0;
//bobbbbbbbbbby add above
assign mem_result   =   inst_ld_b   ? ld_b_result : 
                        inst_ld_bu  ? ld_bu_result:
                        inst_ld_h   ? ld_h_result :
                        inst_ld_hu  ? ld_hu_result: data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

assign out_ms_valid = ms_valid;

endmodule