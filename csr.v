module csr(
    input              reset,
    input              clk,
    input              csr_re,
    input   [13:0]     csr_num,
    output  [31:0]     csr_rvalue,
    output  [31:0]     csr_eentry,
    output  [31:0]     csr_tlbrentry,
    input              csr_we,
    input   [31:0]     csr_wmask,
    input   [31:0]     csr_wvalue,
    input   [5:0]      wb_ecode,
    input   [8:0]      wb_esubcode,
    input              wb_ex,
    input   [31:0]     wb_pc,
    input   [31:0]     wb_vaddr,
    input   [31:0]     coreid_in,
    input              ertn_flush,
    input   [7:0]      hw_int_in,
    output             has_int,
    output  [63:0]     stable_counter_value,
    input              ipi_int_in,
    // tlb instruction
    input   [3:0]      inst_tlb_op,
    // comunication with tlb
    input              r_e,
    input   [18:0]     r_vppn,
    input   [5:0]      r_ps,
    input   [9:0]      r_asid,
    input              r_g,
    input   [19:0]     r_ppn0,
    input   [1:0]      r_plv0,
    input   [1:0]      r_mat0,
    input              r_d0,
    input              r_v0,
    input   [19:0]     r_ppn1,
    input   [1:0]      r_plv1,
    input   [1:0]      r_mat1,
    input              r_d1,
    input              r_v1,
    output  [3:0]      r_index,
    output             we,
    output  [3:0]      w_index,
    output             w_e,
    output  [18:0]     w_vppn,
    output  [5:0]      w_ps,
    output  [9:0]      w_asid,
    output             w_g,
    output  [19:0]     w_ppn0,
    output  [1:0]      w_plv0,
    output  [1:0]      w_mat0,
    output             w_d0,
    output             w_v0,
    output  [19:0]     w_ppn1,
    output  [1:0]      w_plv1,
    output  [1:0]      w_mat1,
    output             w_d1,
    output             w_v1,
    input              s1_found,
    input   [3:0]      s1_index,
    // output for tlb_srch
    output  [31:0]     csr_asid,
    output  [31:0]     csr_tlbehi,
    // to do address translate
    output  [31:0]      csr_dmw0,
    output  [31:0]      csr_dmw1,
    output  [31:0]      csr_crmd
);

// inst_tlb;
wire inst_tlb_fill;
wire inst_tlb_wr;
wire inst_tlb_srch;
wire inst_tlb_rd;
assign {inst_tlb_fill, inst_tlb_wr, inst_tlb_srch, inst_tlb_rd} = inst_tlb_op;

// translate csr_num to csr;
wire  is_csr_crmd;
wire  is_csr_prmd;
wire  is_csr_ecfg;
wire  is_csr_estat;
wire  is_csr_era;
wire  is_csr_badv;
wire  is_csr_eentry;
wire  is_csr_save0;
wire  is_csr_save1;
wire  is_csr_save2;
wire  is_csr_save3;
wire  is_csr_llbctl; 
wire  is_csr_tid;
wire  is_csr_tcfg;
wire  is_csr_tval;
wire  is_csr_ticlr;

assign is_csr_crmd   = (csr_num == 14'h0);
assign is_csr_prmd   = (csr_num == 14'h1);
assign is_csr_ecfg   = (csr_num == 14'h4);
assign is_csr_estat  = (csr_num == 14'h5);
assign is_csr_era    = (csr_num == 14'h6);
assign is_csr_badv   = (csr_num == 14'h7);
assign is_csr_eentry = (csr_num == 14'hc);
assign is_csr_save0  = (csr_num == 14'h30);
assign is_csr_save1  = (csr_num == 14'h31);
assign is_csr_save2  = (csr_num == 14'h32);
assign is_csr_save3  = (csr_num == 14'h33);
assign is_csr_llbctl = (csr_num == 14'h60);
assign is_csr_tid    = (csr_num == 14'h40);
assign is_csr_tcfg   = (csr_num == 14'h41);
assign is_csr_tval   = (csr_num == 14'h42);
assign is_csr_ticlr  = (csr_num == 14'h44);

// translation of tlb
wire  is_csr_tlbidx;
wire  is_csr_tlbehi;
wire  is_csr_tlbelo0;
wire  is_csr_tlbelo1;
wire  is_csr_asid;
wire  is_csr_tlbrentry;
wire  is_csr_dmw0;
wire  is_csr_dmw1;

assign is_csr_tlbidx    = (csr_num == 14'h10);
assign is_csr_tlbehi    = (csr_num == 14'h11);
assign is_csr_tlbelo0   = (csr_num == 14'h12);
assign is_csr_tlbelo1   = (csr_num == 14'h13);
assign is_csr_asid      = (csr_num == 14'h18);
assign is_csr_tlbrentry = (csr_num == 14'h88);
assign is_csr_dmw0      = (csr_num == 14'h180);
assign is_csr_dmw1      = (csr_num == 14'h181);

// translate ecode and esubcode;
wire  is_adef;
wire  is_ale;
wire  is_brk;
wire  is_ine;

assign is_adef = (wb_ecode == 6'h8 && wb_esubcode == 9'h0);
assign is_ale  = (wb_ecode == 6'h9);
assign is_brk  = (wb_ecode == 6'hc);
assign is_ine  = (wb_ecode == 6'hd);

// translate tlb ecode;
wire  is_tlbr;
wire  is_pil;
wire  is_pis;
wire  is_pif;
wire  is_pme;
wire  is_ppi;

assign is_tlbr = (wb_ecode == 6'h3F);
assign is_pil  = (wb_ecode == 6'h1);
assign is_pis  = (wb_ecode == 6'h2);
assign is_pif  = (wb_ecode == 6'h3);
assign is_pme  = (wb_ecode == 6'h4);
assign is_ppi  = (wb_ecode == 6'h7);

// note that csr_{reg_name}_reserve is read-only and always return 0;
// note that we don't consider some domains in csr_crmd and csr_prmd;

// basic csr_regs;
// csr_crmd;
reg  [1:0]   csr_crmd_plv;
reg          csr_crmd_ie;
reg          csr_crmd_da;
reg          csr_crmd_pg;
reg  [1:0]   csr_crmd_datf;
reg  [1:0]   csr_crmd_datm;
assign csr_crmd = {23'b0 , csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

// csr_prmd;
reg  [1:0]   csr_prmd_pplv;
reg          csr_prmd_pie;
wire [31:0]  csr_prmd;
assign csr_prmd = {29'b0, csr_prmd_pie, csr_prmd_pplv};

// csr_ecfg;
reg  [12:0]  csr_ecfg_lie;        // note that csr_ecfg_lie[10] is always zero;
wire [31:0]  csr_ecfg;
assign csr_ecfg = {19'b0, csr_ecfg_lie};

// csr_estat; 
reg  [12:0]  csr_estat_is;
reg  [5:0]   csr_estat_ecode;
reg  [8:0]   csr_estat_esubcode;
wire [31:0]  csr_estat;
assign csr_estat = {1'b0,csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is[12:11], 1'b0, csr_estat_is[9:0]};

// csr_era;
reg  [31:0]  csr_era;

// csr_badv;
reg  [31:0]  csr_badv;

// csr_eentry;
reg  [25:0]  csr_eentry_va;
assign csr_eentry = {csr_eentry_va, 6'b0};

// csr_save0_3;
reg  [31:0]  csr_save0;
reg  [31:0]  csr_save1;
reg  [31:0]  csr_save2;
reg  [31:0]  csr_save3;

// csr_llbctl; 
reg          csr_llbctl_rollb;  // read-only ;
reg          csr_llbctl_wcllb;  // write-1-only ; ignore write-0 ;
reg  [1:0]   csr_llbctl_klo;
wire [31:0]  csr_llbctl;
assign csr_llbctl = {28'b0, csr_llbctl_klo, csr_llbctl_wcllb, csr_llbctl_rollb};

// csr_regs for timer;
// csr_tid;
reg  [31:0]  csr_tid;

// csr_tcfg;
reg          csr_tcfg_en;
reg          csr_tcfg_periodic;
reg  [29:0]  csr_tcfg_initval;
wire [31:0]  csr_tcfg;
assign csr_tcfg = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

// csr_tval;
wire  [31:0]  csr_tval;
wire  [31:0]  tcfg_next_value;
reg   [31:0]  timer_cnt;

// csr_ticlr;
wire         csr_ticlr_clr;   // write-1-only ; ignore write-0 ;
wire [31:0]  csr_ticlr;
assign csr_ticlr = {31'b0, csr_ticlr_clr};

// stable_counter
reg [63:0] stable_counter_r;
assign stable_counter_value = stable_counter_r;

// control csr_crmd_plv and csr_crmd_ie and csr_crmd_da;
always @(posedge clk) begin
    if (reset)  begin
        csr_crmd_plv  <= 2'b0;
        csr_crmd_ie   <= 1'b0;
        csr_crmd_da   <= 1'b1;
        csr_crmd_pg   <= 1'b0;
        csr_crmd_datf <= 2'b0;
        csr_crmd_datm <= 2'b0; 
    end
    else if (wb_ex) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
        if (is_tlbr) begin
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
        end
    end
    else if (ertn_flush) begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie  <= csr_prmd_pie;
        if (csr_estat_ecode == 6'h3F) begin  //tlb_refill
            csr_crmd_da <= 1'b0;
            csr_crmd_pg <= 1'b1;
        end
    end
    else if (csr_we && is_csr_crmd) begin
        csr_crmd_plv  <= csr_wmask[1:0] & csr_wvalue[1:0]
                      | ~csr_wmask[1:0] & csr_crmd_plv;
        csr_crmd_ie   <= csr_wmask[2] & csr_wvalue[2]
                      | ~csr_wmask[2] & csr_crmd_ie;
        csr_crmd_da   <= csr_wmask[3] & csr_wvalue[3]
                      | ~csr_wmask[3] & csr_crmd_da;
        csr_crmd_pg   <= csr_wmask[4] & csr_wvalue[4]
                      | ~csr_wmask[4] & csr_crmd_pg;
        csr_crmd_datf <= csr_wmask[6:5] & csr_wvalue[6:5]
                      | ~csr_wmask[6:5] & csr_crmd_datf;
        csr_crmd_datm <= csr_wmask[8:7] & csr_wvalue[8:7]
                      | ~csr_wmask[8:7] & csr_crmd_datm;
    end
end

// control csr_prmd_pplv and csr_prmd_pie;
always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if (csr_we && is_csr_prmd) begin
        csr_prmd_pplv <= csr_wmask[1:0] & csr_wvalue[1:0]
                      | ~csr_wmask[1:0] & csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[2] & csr_wvalue[2]
                      | ~csr_wmask[2] & csr_prmd_pie;
    end
end

// control csr_ecfg_lie;
always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && is_csr_ecfg)
        csr_ecfg_lie <= csr_wmask[12:0] & csr_wvalue[12:0]
                     | ~csr_wmask[12:0] & csr_ecfg_lie;
end

// control csr_estat_is;
always @(posedge clk) begin
    // software interrupt
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && is_csr_estat)
        csr_estat_is[1:0] <= csr_wmask[1:0] & csr_wvalue[1:0]
                          | ~csr_wmask[1:0] & csr_estat_is[1:0];

    // hardware interrupt
    csr_estat_is[9:2] <= hw_int_in[7:0];

    // reserve
    csr_estat_is[10]  <= 1'b0;

    // timer interrupt
    if (timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && is_csr_ticlr && csr_wmask[0] && csr_wvalue[0])
        csr_estat_is[11] <= 1'b0;
    
    // note that we don't consider Inter-Processor Interrupt here;
    csr_estat_is[12] <= ipi_int_in;
end

// control csr_estat_ecode and csr_estat_esubcode;
always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end 
end

// control csr_era;
always @(posedge clk) begin
    if (wb_ex)
        csr_era <= wb_pc;
    else if (csr_we && is_csr_era)
        csr_era <= csr_wmask[31:0] & csr_wvalue[31:0]
                | ~csr_wmask[31:0] & csr_era;
end

// control csr_badv_vaddr
assign wb_ex_addr_err = is_adef || is_ale || is_tlbr || is_pil || is_pis || is_pif || is_pme || is_ppi;
always @(posedge clk) begin
    if (wb_ex_addr_err && wb_ex)
        csr_badv <= is_adef ? wb_pc : wb_vaddr;
    else if (csr_we && is_csr_badv)
        csr_badv <= csr_wmask[31:0] & csr_wvalue[31:0]
                 | ~csr_wmask[31:0] & csr_badv;
end

// control csr_eentry_va;
always @(posedge clk) begin
    if (csr_we && is_csr_eentry)
        csr_eentry_va <= csr_wmask[31:6] & csr_wvalue[31:6]
                      | ~csr_wmask[31:6] & csr_eentry_va;
end

// control csr_save0_3;
always @(posedge clk) begin
    if (csr_we && is_csr_save0)
        csr_save0 <= csr_wmask[31:0] & csr_wvalue[31:0]
                  | ~csr_wmask[31:0] & csr_save0;
    if (csr_we && is_csr_save1)
        csr_save1 <= csr_wmask[31:0] & csr_wvalue[31:0]
                  | ~csr_wmask[31:0] & csr_save1;
    if (csr_we && is_csr_save2)
        csr_save2 <= csr_wmask[31:0] & csr_wvalue[31:0]
                  | ~csr_wmask[31:0] & csr_save2;
    if (csr_we && is_csr_save3)
        csr_save3 <= csr_wmask[31:0] & csr_wvalue[31:0]
                  | ~csr_wmask[31:0] & csr_save3;
end

// control csr_tid
always @(posedge clk) begin
    if (reset)
        csr_tid = coreid_in;
    else if (csr_we && is_csr_tid)
        csr_tid <= csr_wmask[31:0] & csr_wvalue[31:0]
                | ~csr_wmask[31:0] & csr_tid;
end

// control csr_tcfg_en and csr_tcfg_periodic and csr_tcfg_initval;
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && is_csr_tcfg)
        csr_tcfg_en <= csr_wmask[0] & csr_wvalue[0]
                    | ~csr_wmask[0] & csr_tcfg_en;

    if (csr_we && is_csr_tcfg) begin
        csr_tcfg_periodic <= csr_wmask[1] & csr_wvalue[1]
                          | ~csr_wmask[1] & csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[31:2] & csr_wvalue[31:2]
                         | ~csr_wmask[31:2] & csr_tcfg_initval;
    end
end

// control csr_tval_timeval
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                      | ~csr_wmask[31:0] & csr_tcfg;

always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && is_csr_tcfg && tcfg_next_value[0])
        timer_cnt <= {tcfg_next_value[31:2],2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval[29:0],2'b0};
        else 
            timer_cnt <= timer_cnt - 1'b1;
    end
end

assign csr_tval = timer_cnt;

// control stable_counter_r
always @(posedge clk) begin
    if(reset)
        stable_counter_r <= 64'b0;
    else
        stable_counter_r <= stable_counter_r + 1;
end

// control csr_ticlr_clr
assign csr_ticlr_clr = 1'b0;

// code by JamesYu
// Add csr_tlb regs
// csr_tlbidx
reg  [3:0]   csr_tlbidx_index;
reg  [5:0]   csr_tlbidx_ps;
reg          csr_tlbidx_ne;
wire [31:0]  csr_tlbidx;
assign csr_tlbidx = {csr_tlbidx_ne, 1'b0 , csr_tlbidx_ps, 20'b0, csr_tlbidx_index};

// csr_tlbehi
reg  [18:0]  csr_tlbehi_vppn;
assign csr_tlbehi = {csr_tlbehi_vppn, 13'b0};

// csr_tlbelo0
reg          csr_tlbelo0_v;
reg          csr_tlbelo0_d;
reg  [1:0]   csr_tlbelo0_plv;
reg  [1:0]   csr_tlbelo0_mat;
reg          csr_tlbelo0_g;
reg  [23:0]  csr_tlbelo0_ppn;
wire [31:0]  csr_tlbelo0;
assign csr_tlbelo0 = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};

// csr_tlbelo1
reg          csr_tlbelo1_v;
reg          csr_tlbelo1_d;
reg  [1:0]   csr_tlbelo1_plv;
reg  [1:0]   csr_tlbelo1_mat;
reg          csr_tlbelo1_g;
reg  [23:0]  csr_tlbelo1_ppn;
wire [31:0]  csr_tlbelo1;
assign csr_tlbelo1 = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};

// csr_asid
reg  [9:0]   csr_asid_asid;
// csr_asid_asidbits = 8'd10;
assign csr_asid = {8'b0, 8'd10, 6'b0, csr_asid_asid};

// csr_tlbrentry
reg  [25:0]  csr_tlbrentry_pa;
assign csr_tlbrentry = {csr_tlbrentry_pa, 6'b0};

// csr_dmw0;
reg          csr_dmw0_plv0;
reg          csr_dmw0_plv3;
reg  [1:0]   csr_dmw0_mat;
reg  [2:0]   csr_dmw0_pseg;
reg  [2:0]   csr_dmw0_vseg;
assign csr_dmw0 = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};

// csr_dmw1;
reg          csr_dmw1_plv0;
reg          csr_dmw1_plv3;
reg  [1:0]   csr_dmw1_mat;
reg  [2:0]   csr_dmw1_pseg;
reg  [2:0]   csr_dmw1_vseg;
assign csr_dmw1 = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};

// control csr_tlbidx
always @(posedge clk) begin
    if (reset)
    begin
        csr_tlbidx_index <= 4'b0;
        csr_tlbidx_ps    <= 6'b0;
        csr_tlbidx_ne    <= 1'b1;
    end
    else if (inst_tlb_srch)
    begin
        if (s1_found)
        begin
            csr_tlbidx_index <= s1_index;
            csr_tlbidx_ne    <= 1'b0;
        end
        else
        begin
            csr_tlbidx_ne    <= 1'b1;
        end
    end
    else if (inst_tlb_rd)
    begin
        if (~r_e) 
        begin
            csr_tlbidx_ps <= 6'b0;
            csr_tlbidx_ne <= 1'b1;
        end
        else
        begin
            csr_tlbidx_ps <= r_ps;
            csr_tlbidx_ne <= 1'b0;
        end
    end
    else if (csr_we && is_csr_tlbidx)
    begin
        csr_tlbidx_ne <= csr_wmask[31] & csr_wvalue[31]
                      | ~csr_wmask[31] & csr_tlbidx_ne;
        csr_tlbidx_ps <= csr_wmask[29:24] & csr_wvalue[29:24]
                      | ~csr_wmask[29:24] & csr_tlbidx_ps;
        csr_tlbidx_index <= csr_wmask[3:0] & csr_wvalue[3:0]
                         | ~csr_wmask[3:0] & csr_tlbidx_index;
    end
end

// control csr_tlbehi
always @(posedge clk) begin
    if (reset)
    begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if (inst_tlb_rd)
    begin
        if (~r_e) 
        begin
            csr_tlbehi_vppn <= 19'b0;
        end
        else
        begin
            csr_tlbehi_vppn <= r_vppn;
        end
    end
    else if (is_tlbr || is_pil || is_pis || is_pif || is_pme || is_ppi)
    begin
        csr_tlbehi_vppn <= wb_vaddr[31:13];
    end
    else if (csr_we && is_csr_tlbehi)
    begin
        csr_tlbehi_vppn <= csr_wmask[31:13] & csr_wvalue[31:13]
                        | ~csr_wmask[31:13] & csr_tlbehi_vppn;
    end
end

// control csr_tlbelo0
always @(posedge clk) begin
    if (reset)
    begin
        csr_tlbelo0_v    <= 1'b0;
        csr_tlbelo0_d    <= 1'b0;
        csr_tlbelo0_plv  <= 2'b0;
        csr_tlbelo0_mat  <= 2'b0;
        csr_tlbelo0_g    <= 1'b0;
        csr_tlbelo0_ppn  <= 24'b0;
    end
    else if (inst_tlb_rd)
    begin
        if (~r_e)
        begin
            csr_tlbelo0_v    <= 1'b0;
            csr_tlbelo0_d    <= 1'b0;
            csr_tlbelo0_plv  <= 2'b0;
            csr_tlbelo0_mat  <= 2'b0;
            csr_tlbelo0_g    <= 1'b0;
            csr_tlbelo0_ppn  <= 24'b0;
        end
        else 
        begin
            csr_tlbelo0_v    <= r_v0;
            csr_tlbelo0_d    <= r_d0;
            csr_tlbelo0_plv  <= r_plv0;
            csr_tlbelo0_mat  <= r_mat0;
            csr_tlbelo0_g    <= r_g;
            csr_tlbelo0_ppn  <= r_ppn0;
        end
    end
    else if (csr_we && is_csr_tlbelo0)
    begin
        csr_tlbelo0_v   <= csr_wmask[0] & csr_wvalue[0]
                        | ~csr_wmask[0] & csr_tlbelo0_v;
        csr_tlbelo0_d   <= csr_wmask[1] & csr_wvalue[1]
                        | ~csr_wmask[1] & csr_tlbelo0_d;
        csr_tlbelo0_plv <= csr_wmask[3:2] & csr_wvalue[3:2]
                        | ~csr_wmask[3:2] & csr_tlbelo0_plv;
        csr_tlbelo0_mat <= csr_wmask[5:4] & csr_wvalue[5:4]
                        | ~csr_wmask[5:4] & csr_tlbelo0_mat;
        csr_tlbelo0_g   <= csr_wmask[6] & csr_wvalue[6]
                        | ~csr_wmask[6] & csr_tlbelo0_g;
        csr_tlbelo0_ppn <= csr_wmask[31:8] & csr_wvalue[31:8]
                        | ~csr_wmask[31:8] & csr_tlbelo0_ppn;
    end
end

// control csr_tlbelo1
always @(posedge clk) begin
    if (reset)
    begin
        csr_tlbelo1_v    <= 1'b0;
        csr_tlbelo1_d    <= 1'b0;
        csr_tlbelo1_plv  <= 2'b0;
        csr_tlbelo1_mat  <= 2'b0;
        csr_tlbelo1_g    <= 1'b0;
        csr_tlbelo1_ppn  <= 24'b0;
    end
    else if (inst_tlb_rd)
    begin
        if (~r_e)
        begin
            csr_tlbelo1_v    <= 1'b0;
            csr_tlbelo1_d    <= 1'b0;
            csr_tlbelo1_plv  <= 2'b0;
            csr_tlbelo1_mat  <= 2'b0;
            csr_tlbelo1_g    <= 1'b0;
            csr_tlbelo1_ppn  <= 24'b0;
        end
        else
        begin
            csr_tlbelo1_v    <= r_v1;
            csr_tlbelo1_d    <= r_d1;
            csr_tlbelo1_plv  <= r_plv1;
            csr_tlbelo1_mat  <= r_mat1;
            csr_tlbelo1_g    <= r_g;
            csr_tlbelo1_ppn  <= r_ppn1;
        end
    end
    else if (csr_we && is_csr_tlbelo1)
    begin
        csr_tlbelo1_v   <= csr_wmask[0] & csr_wvalue[0]
                        | ~csr_wmask[0] & csr_tlbelo1_v;
        csr_tlbelo1_d   <= csr_wmask[1] & csr_wvalue[1]
                        | ~csr_wmask[1] & csr_tlbelo1_d;
        csr_tlbelo1_plv <= csr_wmask[3:2] & csr_wvalue[3:2]
                        | ~csr_wmask[3:2] & csr_tlbelo1_plv;
        csr_tlbelo1_mat <= csr_wmask[5:4] & csr_wvalue[5:4]
                        | ~csr_wmask[5:4] & csr_tlbelo1_mat;
        csr_tlbelo1_g   <= csr_wmask[6] & csr_wvalue[6]
                        | ~csr_wmask[6] & csr_tlbelo1_g;
        csr_tlbelo1_ppn <= csr_wmask[31:8] & csr_wvalue[31:8]
                        | ~csr_wmask[31:8] & csr_tlbelo1_ppn;
    end
end

// control csr_asid
always @(posedge clk) begin
    if (reset)
    begin
        csr_asid_asid <= 10'b0;
    end
    else if (inst_tlb_rd)
    begin
        if (~r_e)
        begin
            csr_asid_asid <= 10'b0;
        end
        else
        begin
            csr_asid_asid <= r_asid;
        end
    end
    else if (csr_we && is_csr_asid)
    begin
        csr_asid_asid <= csr_wmask[9:0] & csr_wvalue[9:0]
                      | ~csr_wmask[9:0] & csr_asid_asid;
    end
end

// control csr_tlbrentry
always @(posedge clk) begin
    if (reset)
    begin
        csr_tlbrentry_pa <= 26'b0;
    end
    else if (csr_we && is_csr_tlbrentry)
    begin
        csr_tlbrentry_pa <= csr_wmask[31:6] & csr_wvalue[31:6]
                         | ~csr_wmask[31:6] & csr_tlbrentry_pa;
    end
end

// control csr_dmw0
always @(posedge clk) begin
    if (reset)
    begin
        csr_dmw0_plv0 <= 1'b0;
        csr_dmw0_plv3 <= 1'b0;
        csr_dmw0_mat  <= 2'b0;
        csr_dmw0_pseg <= 3'b0;
        csr_dmw0_vseg <= 3'b0;
    end
    else if (csr_we && is_csr_dmw0)
    begin
        csr_dmw0_plv0 <= csr_wmask[0] & csr_wvalue[0]
                      | ~csr_wmask[0] & csr_dmw0_plv0;
        csr_dmw0_plv3 <= csr_wmask[3] & csr_wvalue[3]
                      | ~csr_wmask[3] & csr_dmw0_plv3;
        csr_dmw0_mat  <= csr_wmask[5:4] & csr_wvalue[5:4]
                      | ~csr_wmask[5:4] & csr_dmw0_mat;
        csr_dmw0_pseg <= csr_wmask[27:25] & csr_wvalue[27:25]
                      | ~csr_wmask[27:25] & csr_dmw0_pseg;
        csr_dmw0_vseg <= csr_wmask[31:29] & csr_wvalue[31:29]
                      | ~csr_wmask[31:29] & csr_dmw0_vseg;
    end
end

// control csr_dmw1
always @(posedge clk) begin
    if (reset)
    begin
        csr_dmw1_plv0 <= 1'b0;
        csr_dmw1_plv3 <= 1'b0;
        csr_dmw1_mat  <= 2'b0;
        csr_dmw1_pseg <= 3'b0;
        csr_dmw1_vseg <= 3'b0;
    end
    else if (csr_we && is_csr_dmw1)
    begin
        csr_dmw1_plv0 <= csr_wmask[0] & csr_wvalue[0]
                      | ~csr_wmask[0] & csr_dmw1_plv0;
        csr_dmw1_plv3 <= csr_wmask[3] & csr_wvalue[3]
                      | ~csr_wmask[3] & csr_dmw1_plv3;
        csr_dmw1_mat  <= csr_wmask[5:4] & csr_wvalue[5:4]
                      | ~csr_wmask[5:4] & csr_dmw1_mat;
        csr_dmw1_pseg <= csr_wmask[27:25] & csr_wvalue[27:25]
                      | ~csr_wmask[27:25] & csr_dmw1_pseg;
        csr_dmw1_vseg <= csr_wmask[31:29] & csr_wvalue[31:29]
                      | ~csr_wmask[31:29] & csr_dmw1_vseg;
    end
end

// randomly choose tlbfill_index;
reg [3:0]   tlbfill_index;
always @(posedge clk) begin
    if (reset)
    begin
        tlbfill_index <= 4'b0;
    end
    else if (inst_tlb_fill)
    begin
        if (tlbfill_index == 4'b1111)
        begin
            tlbfill_index <= 4'b0;
        end
        else
        begin
            tlbfill_index <= tlbfill_index + 4'b1;
        end
    end
end

// output for csr
assign we       = inst_tlb_wr || inst_tlb_fill;
assign w_index  = inst_tlb_fill ? tlbfill_index : csr_tlbidx_index;
assign w_e      = ~csr_tlbidx_ne;
assign w_vppn   = csr_tlbehi_vppn;
assign w_ps     = csr_tlbidx_ps;
assign w_asid   = csr_asid_asid;
assign w_g      = csr_tlbelo0_g && csr_tlbelo1_g;
assign w_ppn0   = csr_tlbelo0_ppn;
assign w_plv0   = csr_tlbelo0_plv;
assign w_mat0   = csr_tlbelo0_mat;
assign w_d0     = csr_tlbelo0_d;
assign w_v0     = csr_tlbelo0_v;
assign w_ppn1   = csr_tlbelo1_ppn;
assign w_plv1   = csr_tlbelo1_plv;
assign w_mat1   = csr_tlbelo1_mat;
assign w_d1     = csr_tlbelo1_d;
assign w_v1     = csr_tlbelo1_v;
assign r_index  = csr_tlbidx_index;

assign csr_rvalue = (({32{is_csr_crmd}} & csr_crmd)
                  | ({32{is_csr_prmd}} & csr_prmd)
                  | ({32{is_csr_ecfg}} & csr_ecfg)
                  | ({32{is_csr_estat}} & csr_estat)
                  | ({32{is_csr_era}} & csr_era)
                  | ({32{is_csr_badv}} & csr_badv)
                  | ({32{is_csr_eentry}} & csr_eentry)
                  | ({32{is_csr_save0}} & csr_save0)
                  | ({32{is_csr_save1}} & csr_save1)
                  | ({32{is_csr_save2}} & csr_save2)
                  | ({32{is_csr_save3}} & csr_save3)
                  | ({32{is_csr_llbctl}} & csr_llbctl)
                  | ({32{is_csr_tid}} & csr_tid)
                  | ({32{is_csr_tcfg}} & csr_tcfg)
                  | ({32{is_csr_tval}} & csr_tval)
                  | ({32{is_csr_ticlr}} & csr_ticlr)
                  | ({32{is_csr_asid}} & csr_asid)
                  | ({32{is_csr_tlbidx}} & csr_tlbidx)
                  | ({32{is_csr_tlbehi}} & csr_tlbehi)
                  | ({32{is_csr_tlbelo0}} & csr_tlbelo0)
                  | ({32{is_csr_tlbrentry}} & csr_tlbrentry)
                  | ({32{is_csr_tlbelo1}} & csr_tlbelo1)
                  | ({32{is_csr_dmw0}} & csr_dmw0)
                  | ({32{is_csr_dmw1}} & csr_dmw1)) & {32{csr_re}};

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);

endmodule
