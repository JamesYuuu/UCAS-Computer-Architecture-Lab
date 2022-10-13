module ID_stage(
    input           clk,
    input           reset,
    // allowin
    input           es_allowin,
    output          ds_allowin,
    // input from IF stage
    input           fs_to_ds_valid,
    input   [63:0]  fs_to_ds_bus,
    // output for EXE stage
    output          ds_to_es_valid,
    output  [201:0] ds_to_es_bus,
    // branch bus
    output  [33:0]  br_bus,
    // input from WB stage for reg_file
    input   [38:0]  rf_bus,
    // input for hazard
    input           out_ms_valid,
    input           out_es_valid,
    input   [103:0] ms_to_ws_bus,
    input   [109:0] es_to_ms_bus,
    // interrupt signal
    input           wb_ex
);

reg         ds_valid;
wire        ds_ready_go;
reg  [63:0] fs_to_ds_bus_r;

wire [31:0] ds_pc;
wire [31:0] ds_inst;

wire        br_taken;
wire [31:0] br_target;
wire        br_taken_cancel;

wire [11:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire [3: 0] mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [4:0]  ms_addr;
wire [4:0]  es_addr;
wire        ms_we;
wire        es_we;
wire        src1_hazard;
wire        src2_hazard;
wire        either_hazard;
wire        hazard;
wire        both_src;
wire        src1;
wire        src2;
wire        ms_valid;
wire        es_valid;
wire        ws_valid;
wire        es_res_from_mem;
wire [31:0] es_result;
wire [31:0] ms_result;

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];

// bob add below
wire inst_slti;
wire inst_sltui;
wire inst_andi;
wire inst_ori;
wire inst_xori;
wire inst_sll_w;
wire inst_srl_w;
wire inst_sra_w;
wire inst_pcaddu12i;

wire inst_mul_w;
wire inst_mulh_w;
wire inst_mulh_wu;

wire inst_div_w;
wire inst_mod_w;
wire inst_div_wu;
wire inst_mod_wu;

assign inst_slti    = op_31_26_d[6'b000000] & op_25_22_d[4'b1000];
assign inst_sltui   = op_31_26_d[6'b000000] & op_25_22_d[4'b1001];
assign inst_andi    = op_31_26_d[6'b000000] & op_25_22_d[4'b1101];
assign inst_ori     = op_31_26_d[6'b000000] & op_25_22_d[4'b1110];
assign inst_xori    = op_31_26_d[6'b000000] & op_25_22_d[4'b1111];
assign inst_sll_w   = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b01110];
assign inst_srl_w   = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b01111];
assign inst_sra_w   = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b10000];
assign inst_pcaddu12i = op_31_26_d[6'b000111] & ~ds_inst[25];

assign inst_mul_w   = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b11000];
assign inst_mulh_w  = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b11001];
assign inst_mulh_wu = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b11010];

assign inst_div_w   = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b10] & op_19_15_d[5'b00000];
assign inst_mod_w   = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b10] & op_19_15_d[5'b00001];
assign inst_div_wu  = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b10] & op_19_15_d[5'b00010];
assign inst_mod_wu  = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b10] & op_19_15_d[5'b00011];
wire need_ui12;
wire rj_eq_rd;
wire rj_above_rd;
wire rj_above_rd_u;
// bob add above

// code by JamesYu
// add new branch inst
wire    inst_blt;
wire    inst_bge;
wire    inst_bltu;
wire    inst_bgeu;
wire    br_con;
wire    br_uncon;

assign  inst_blt   = op_31_26_d[6'b011000];
assign  inst_bge   = op_31_26_d[6'b011001];
assign  inst_bltu  = op_31_26_d[6'b011010];
assign  inst_bgeu  = op_31_26_d[6'b011011];
assign  br_con     = inst_blt | inst_bge | inst_bgeu | inst_bltu | inst_bne | inst_beq;
assign  br_uncon   = inst_bl | inst_b;

//bobbbbbbbbbby add below
wire    inst_ld_b;
wire    inst_ld_h;
wire    inst_ld_bu;
wire    inst_ld_hu;
wire    inst_st_b;
wire    inst_st_h;

assign  inst_ld_b = op_31_26_d[6'b001010] & op_25_22_d[4'b0000];
assign  inst_ld_h = op_31_26_d[6'b001010] & op_25_22_d[4'b0001];
assign  inst_st_b = op_31_26_d[6'b001010] & op_25_22_d[4'b0100];
assign  inst_st_h = op_31_26_d[6'b001010] & op_25_22_d[4'b0101];
assign  inst_ld_bu= op_31_26_d[6'b001010] & op_25_22_d[4'b1000];
assign  inst_ld_hu= op_31_26_d[6'b001010] & op_25_22_d[4'b1001];
//bobbbbbbbbbby add above

//bobbbbbbbbbby add below
wire inst_csrrd;        // from csr to grf
wire inst_csrwr;        // from grf to csr
wire inst_csrxchg;      // rj is a mask, rd with mask write to csr
wire inst_ertn;
wire inst_syscall;
wire [14:0] csr_code;
wire [13:0] csr_num;

assign inst_syscall = op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b10] & op_19_15_d[5'b10110];
assign csr_code = ds_inst[14:0];

assign inst_csrrd = op_31_26_d[6'b000001] & (ds_inst[25:24] == 2'b00) & (ds_inst[9:5] == 5'b00000);
assign inst_csrwr = op_31_26_d[6'b000001] & (ds_inst[25:24] == 2'b00) & (ds_inst[9:5] == 5'b00001);
assign inst_csrxchg = op_31_26_d[6'b000001] & (ds_inst[25:24] == 2'b00) & (~inst_csrrd) & (~inst_csrwr);
assign inst_ertn = op_31_26_d[6'b000001] & op_25_22_d[4'b1001] & op_21_20_d[2'b00] & op_19_15_d[5'b10000] & (ds_inst[14:10] == 5'b01110) & (ds_inst[9:0] == 0);
assign csr_num = ds_inst[23:10];

wire  [4:0]   csr_op;
wire  [33:0]  csr_data;
assign csr_op   = {inst_csrrd, inst_csrwr, inst_csrxchg, inst_ertn, inst_syscall};
assign csr_data = {csr_op,csr_num,csr_code};

//bobbbbbbbbbby add above


assign alu_op[ 0] = inst_add_w  | inst_addi_w   | inst_ld_w | inst_st_w
                                | inst_jirl     | inst_bl   | inst_pcaddu12i
                                | inst_ld_b     | inst_ld_h | inst_ld_bu
                                | inst_ld_hu    | inst_st_b | inst_st_h;   //add
assign alu_op[ 1] = inst_sub_w;                                                 //sub
assign alu_op[ 2] = inst_slt    | inst_slti;                                    //slt
assign alu_op[ 3] = inst_sltu   | inst_sltui;                                   //sltu
assign alu_op[ 4] = inst_and    | inst_andi;                                    //and
assign alu_op[ 5] = inst_nor;                                                   //nor
assign alu_op[ 6] = inst_or     | inst_ori;                                     //or
assign alu_op[ 7] = inst_xor    | inst_xori;                                    //xor
assign alu_op[ 8] = inst_slli_w | inst_sll_w;                                   //sll
assign alu_op[ 9] = inst_srli_w | inst_srl_w;                                   //srl
assign alu_op[10] = inst_srai_w | inst_sra_w;                                   //sra
assign alu_op[11] = inst_lu12i_w;                                               //lu12i

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h;
assign need_si16  =  inst_jirl | br_con ;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;
//bob add below
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
//bob add above

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui12 ? {20'b0, i12[11:0]}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{4{i26[25]}}, i26[25:0], 2'b0} : 
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = br_con | inst_st_w | inst_st_h | inst_st_b | inst_csrwr; 

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_ld_b   |
                       inst_ld_h   |
                       inst_ld_bu  |
                       inst_ld_hu  |
                       inst_st_b   |
                       inst_st_h   |
                       inst_pcaddu12i; 

assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_b & ~br_con & ~inst_st_b & ~inst_st_h;
assign mem_we        =  inst_st_w ? 4'b1111 : 
                        inst_st_h ? 4'b0011 :
                        inst_st_b ? 4'b0001 : 4'b0000;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_eq_rd      = (rj_value == rkd_value);
assign rj_above_rd   = ($signed(rj_value) >= $signed(rkd_value));
assign rj_above_rd_u = (rj_value >= rkd_value);

assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_bge  &&  rj_above_rd
                   || inst_bgeu &&  rj_above_rd_u
                   || inst_blt  && !rj_above_rd
                   || inst_bltu && !rj_above_rd_u 
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && ds_valid;
assign br_target = (br_con || br_uncon) ? (ds_pc + br_offs) : /*inst_jirl*/ (rj_value + jirl_offs);
// deal with input and output
assign br_bus                    = {br_taken_cancel,br_taken,br_target};
assign {ds_inst,ds_pc}           = fs_to_ds_bus_r;

assign {ws_valid,rf_we,rf_waddr,rf_wdata} = rf_bus;

// add div mul load and store inst
wire [6:0] divmul_op;
wire [7:0] ldst_op;
assign divmul_op                 = {inst_mul_w,inst_mulh_w,inst_mulh_wu,inst_div_w,inst_mod_w,inst_div_wu,inst_mod_wu};
assign ldst_op                   = {inst_ld_b,inst_ld_bu,inst_ld_h,inst_ld_hu,inst_ld_w,inst_st_b,inst_st_h,inst_st_w};

assign ds_to_es_bus              = {alu_op, src1_is_pc, ds_pc, rj_value, src2_is_imm, imm, rkd_value, gr_we, dest, res_from_mem, mem_we, divmul_op , ldst_op ,csr_data};

assign ds_ready_go      = !(hazard && es_res_from_mem && es_valid);
assign ds_allowin       = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid   = ds_valid && ds_ready_go;
assign br_taken_cancel  = br_taken && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <=1'b0;
    end
    else if(wb_ex) begin
        ds_valid <= 1'b0;
    end
    else if (br_taken_cancel) begin
        ds_valid <=1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
end

always @(posedge clk) begin
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign ms_valid = out_ms_valid;
assign es_valid = out_es_valid;

assign {es_res_from_mem,es_we,es_addr,es_result} = es_to_ms_bus[70:32];
assign {ms_we,ms_addr,ms_result} = ms_to_ws_bus[69:32];

// read after write hazard
assign src1_hazard = (rf_raddr1 == 5'b0) ? 1'b0:
                     (rf_raddr1 == ms_addr && ms_we && ms_valid) ? 1'b1:
                     (rf_raddr1 == es_addr && es_we && es_valid) ? 1'b1:
                     (rf_raddr1 == rf_waddr && rf_we && ws_valid) ? 1'b1 : 1'b0;
assign src2_hazard = (rf_raddr2 == 5'b0) ? 1'b0:
                     (rf_raddr2 == ms_addr && ms_we && ms_valid) ? 1'b1:
                     (rf_raddr2 == es_addr && es_we && es_valid) ? 1'b1:
                     (rf_raddr2 == rf_waddr && rf_we && ws_valid) ? 1'b1 : 1'b0; 

assign either_hazard = src1_hazard || src2_hazard;
assign both_src = inst_add_w || inst_sub_w || inst_slt || inst_nor || inst_and || inst_or || inst_xor || inst_beq || inst_bne || inst_sltu || inst_sll_w || inst_srl_w || inst_sra_w || inst_mul_w || inst_mulh_w || inst_mulh_wu || inst_div_w || inst_mod_w || inst_div_wu || inst_mod_wu;
assign src1 = inst_slli_w || inst_srli_w || inst_srai_w || inst_addi_w || inst_jirl || inst_slti || inst_sltui || inst_andi || inst_ori || inst_xori || inst_ld_b || inst_ld_bu || inst_ld_h || inst_ld_hu || inst_ld_w;
assign src2 = inst_st_w | inst_st_b | inst_st_h;

assign hazard      = (both_src && either_hazard) ? 1'b1:
                     (src1     && src1_hazard) ?   1'b1: 
                     (src2     && src2_hazard) ?   1'b1: 1'b0;

// data forward
assign rj_value  = (rf_raddr1 == es_addr && es_we && !es_res_from_mem && out_es_valid)? es_result :
                   (rf_raddr1 == ms_addr && ms_we && out_ms_valid)? ms_result:
                   (rf_raddr1 == rf_waddr && rf_we && ws_valid) ? rf_wdata : rf_rdata1;

assign rkd_value = (rf_raddr2 == es_addr && es_we && !es_res_from_mem && out_es_valid)? es_result :
                   (rf_raddr2 == ms_addr && ms_we && out_ms_valid)? ms_result:
                   (rf_raddr2 == rf_waddr && rf_we && ws_valid) ? rf_wdata : rf_rdata2;

endmodule
