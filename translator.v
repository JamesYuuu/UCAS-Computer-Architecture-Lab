module translator
(
    input wire  [31:0]  addr,
    input wire  [31:0]  csr_dmw0,
    input wire  [31:0]  csr_dmw1,
    input wire  [31:0]  csr_crmd,
    
    output  wire [31:0]  physical_addr,
    output  wire using_page_table,
    output  wire ade
);
wire crmd_da;
wire crmd_pg;
wire [1:0] crmd_plv;
assign crmd_plv = csr_crmd[1:0];
assign crmd_da = csr_crmd[3];
assign crmd_pg = csr_crmd[4];

wire            dmw0_plv0;
wire            dmw0_plv3;
wire    [1:0]   dmw0_mat;
wire    [2:0]   dmw0_pseg;
wire    [2:0]   dmw0_vseg;
wire            dmw1_plv0;
wire            dmw1_plv3;
wire    [1:0]   dmw1_mat;
wire    [2:0]   dmw1_pseg;
wire    [2:0]   dmw1_vseg;
assign dmw0_plv0 = csr_dmw0[0];
assign dmw0_plv3 = csr_dmw0[3];
assign dmw1_plv0 = csr_dmw1[0];
assign dmw1_plv3 = csr_dmw1[3];
assign dmw0_mat  = csr_dmw0[5:4];
assign dmw1_mat  = csr_dmw1[5:4];
assign dmw0_pseg = csr_dmw0[27:25];
assign dmw1_pseg = csr_dmw1[27:25];
assign dmw0_vseg = csr_dmw0[31:29];
assign dmw1_vseg = csr_dmw1[31:29];

wire direct_mode;
wire map_mode;
assign  direct_mode = crmd_da  & ~crmd_pg;
assign  map_mode    = ~crmd_da & crmd_pg;

wire using_dmw0;
wire using_dmw1;
assign using_dmw0 = (crmd_plv == 2'b0 & dmw0_plv0 | crmd_plv == 2'b11 & dmw0_plv3) &
                    (addr[31:29] == dmw0_vseg);
assign using_dmw1 = (crmd_plv == 2'b0 & dmw1_plv0 | crmd_plv == 2'b11 & dmw1_plv3) &
                    (addr[31:29] == dmw1_vseg);

wire [31:0] dmw0_physical_addr;
wire [31:0] dmw1_physical_addr;
assign dmw0_physical_addr = {dmw0_pseg, addr[28:0]};
assign dmw1_physical_addr = {dmw1_pseg, addr[28:0]};

assign physical_addr =  direct_mode ? addr :
                        using_dmw0 ? dmw0_physical_addr :
                        using_dmw1 ? dmw1_physical_addr : 0;
assign using_page_table = ~direct_mode & ~using_dmw0 & ~using_dmw1;

assign ade = ~using_dmw1 & ~using_dmw0 & ~direct_mode & addr[31];

endmodule