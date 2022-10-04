module EXE_stage(
    input               clk,
    input               reset,
    // allowin
    input               ms_allowin,
    output              es_allowin,
    // input from ID stage
    input               ds_to_es_valid,
    input   [156:0]     ds_to_es_bus,
    // output for MEM stage
    output              es_to_ms_valid,
    output  [70:0]      es_to_ms_bus,
    // data sram interface
    output wire         data_sram_en,
    output wire [3:0]   data_sram_we,
    output wire [31:0]  data_sram_addr,
    output wire [31:0]  data_sram_wdata,
    // output es_valid and bus for ID stage
    output              out_es_valid
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
reg [156:0] ds_to_es_bus_r;

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

// code by JamesYu
// add control signals
wire [6:0] divmul_op;
wire inst_mul_w;
wire inst_mulh_w;
wire inst_mulh_wu;
wire inst_div_w;
wire inst_mod_w;
wire inst_div_wu;
wire inst_mod_wu;
wire is_mul;
wire is_div;
assign {inst_mul_w,inst_mulh_w,inst_mulh_wu,inst_div_w,inst_mod_w,inst_div_wu,inst_mod_wu} = divmul_op;
assign is_mul = inst_mul_w | inst_mulh_w | inst_mulh_wu;
assign is_div = inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu;

// add multiple support
wire [32:0] mul_src1;
wire [32:0] mul_src2;
wire [65:0] signed_result;
wire [31:0] mul_result;
assign mul_src1 = (inst_mulh_w) ? {alu_src1[31],alu_src1} : {1'b0,alu_src1};
assign mul_src2 = (inst_mulh_w) ? {alu_src2[31],alu_src2} : {1'b0,alu_src2};
assign signed_result = $signed(mul_src1) * $signed(mul_src2);
assign mul_result = (inst_mul_w) ? signed_result[31:0] : signed_result[63:32];

// add divison support
wire [31:0] div_result;

//bob add div part
reg div_signed_valid;
reg div_unsigned_valid;
reg div_signed_got;
reg div_unsigned_got;
wire div_signed_ready_divisor;
wire div_signed_ready_dividend;
wire div_unsigned_ready_divisor;
wire div_unsigned_ready_dividend;
wire div_signed_result_valid;
wire div_unsigned_result_valid;
wire [31:0] div_signed_result;
wire [31:0] mod_signed_result;
wire [31:0] div_unsigned_result;
wire [31:0] mod_unsigned_result;

always @ (posedge clk)
begin
    if(inst_div_w | inst_mod_w)
    begin
        if(div_signed_ready_divisor && div_signed_ready_dividend)
        begin
            div_signed_valid <= 0;
            div_signed_got <= 1;
        end
        else if(~div_signed_got)
        begin
            div_signed_valid <= 1;
        end        
        else if(div_signed_got && div_signed_result_valid)
            div_signed_got <= 0;
    end
    else if(inst_div_wu | inst_mod_wu)
    begin
        if(div_unsigned_ready_divisor && div_unsigned_ready_dividend)
        begin
            div_unsigned_valid <= 0;
            div_unsigned_got <= 1;
        end
        else if(~div_unsigned_got)
        begin
            div_unsigned_valid <= 1;
        end
        else if(div_unsigned_got && div_unsigned_result_valid)
            div_unsigned_got <= 0;
    end
    else
    begin
        div_signed_got <= 0;
        div_unsigned_got <= 0;
    end
end

module_div_signed div_signed(
                    .s_axis_divisor_tdata(alu_src2), 
                    .s_axis_divisor_tready(div_signed_ready_divisor),
                    .s_axis_divisor_tvalid(div_signed_valid),
                    .s_axis_dividend_tdata(alu_src1),
                    .s_axis_dividend_tready(div_signed_ready_dividend),
                    .s_axis_dividend_tvalid(div_signed_valid),
                    .m_axis_dout_tdata({div_signed_result, mod_signed_result}),
                    .m_axis_dout_tvalid(div_signed_result_valid),
                    .aclk(clk)
                 );

module_div_unsigned div_unsigned(
                    .s_axis_divisor_tdata(alu_src2), 
                    .s_axis_divisor_tready(div_unsigned_ready_divisor),
                    .s_axis_divisor_tvalid(div_unsigned_valid),
                    .s_axis_dividend_tdata(alu_src1),
                    .s_axis_dividend_tready(div_unsigned_ready_dividend),
                    .s_axis_dividend_tvalid(div_unsigned_valid),
                    .m_axis_dout_tdata({div_unsigned_result, mod_unsigned_result}),
                    .m_axis_dout_tvalid(div_unsigned_result_valid),
                    .aclk(clk)
                 );

assign div_result = inst_div_w ? div_signed_result :
                    inst_mod_w ? mod_signed_result :
                    inst_div_wu? div_unsigned_result :
                    inst_mod_wu? mod_unsigned_result : 0;
//bob add div part
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

assign es_ready_go    = ~((inst_div_w | inst_mod_w) && (~div_signed_result_valid)) & ~((inst_div_wu | inst_mod_wu) && (~div_unsigned_result_valid));
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;

// add result select
wire [31:0] write_result;
assign write_result = (is_mul) ? mul_result :
                      (is_div) ? div_result :   alu_result;

// deal with input and output
assign {alu_op,src1_is_pc,pc,rj_value,src2_is_imm,imm,rkd_value,gr_we,dest,res_from_mem,mem_we,divmul_op}=ds_to_es_bus_r;
assign es_to_ms_bus = {res_from_mem,gr_we,dest,write_result,pc};

assign data_sram_we    = es_valid ? mem_we : 4'b0;//mem_we && es_valid? 4'hF : 4'h0;
assign data_sram_en    = 1'h1;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

assign out_es_valid = es_valid;

endmodule