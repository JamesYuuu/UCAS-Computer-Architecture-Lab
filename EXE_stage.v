module EXE_stage(
    input               clk,
    input               reset,
    // allowin
    input               ms_allowin,
    output              es_allowin,
    // input from ID stage
    input               ds_to_es_valid,
    input   [149:0]     ds_to_es_bus,
    // output for MEM stage
    output              es_to_ms_valid,
    output  [70:0]      es_to_ms_bus,
    // data sram interface
    output wire         data_sram_en,
    output wire [3:0]   data_sram_we,
    output wire [31:0]  data_sram_addr,
    output wire [31:0]  data_sram_wdata
);

wire [11:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        gr_we;
wire        res_from_mem;
wire        mem_we;
wire [31:0] pc;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;
reg [149:0] ds_to_es_bus_r;

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

reg     es_valid;
wire    es_ready_go;

assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end
    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end


// deal with input and output
assign {alu_op,src1_is_pc,pc,rj_value,src2_is_imm,imm,rkd_value,gr_we,dest,res_from_mem,mem_we}=ds_to_es_bus_r;
assign es_to_ms_bus = {res_from_mem,gr_we,dest,alu_result,pc};

assign data_sram_we    = mem_we && es_valid? 4'hF : 4'h0;
assign data_sram_en    = 1'h1;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

endmodule