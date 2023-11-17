property ResetCondition;
    @(posedge clk) reset |=> (s0_pc == `PC_RESET);
endproperty

property StypeWmaskNumberofOneSB;
    @(posedge clk) (s1_inst[14:12] == `FNC_SB && s1_inst[6:0] == `OPC_STORE) |-> (dcache_we[0] + dcache_we[1] + dcache_we[2] + dcache_we[3] <= 1);
endproperty

property StypeWmaskNumberofOneSH;
    @(posedge clk) (s1_inst[14:12] == `FNC_SH && s1_inst[6:0] == `OPC_STORE) |-> (dcache_we[0] + dcache_we[1] + dcache_we[2] + dcache_we[3] <= 2);
endproperty

property StypeWmaskNumberofOneSW;
    @(posedge clk) (s1_inst[14:12] == `FNC_SW && s1_inst[6:0] == `OPC_STORE) |-> (dcache_we[0] + dcache_we[1] + dcache_we[2] + dcache_we[3] <= 4);
endproperty

property UpperImmediateLB;
    @(posedge clk) ((control.s2_inst[6:0] == `OPC_LOAD) && (control.s2_inst[14:12]) == `FNC_LB) |-> ((s2_dataD[`CPU_DATA_BITS-1:8] == {24{1'b1}}) || (s2_dataD[`CPU_DATA_BITS-1:8] == {24{1'b0}}));
endproperty

property UpperImmediateLH;
    @(posedge clk) ((control.s2_inst[6:0] == `OPC_LOAD) && (control.s2_inst[14:12]) == `FNC_LH) |-> ((s2_dataD[`CPU_DATA_BITS-1:16] == {16{1'b1}}) || (s2_dataD[`CPU_DATA_BITS-1:16] == {16{1'b0}}));  
endproperty

property ZeroRegisterMustBeZeroA;
   @(posedge clk) (s1_inst[19:15] == 0) |-> (s1_dataA == 0);
endproperty

property ZeroRegisterMustBeZeroB;
    @(posedge clk) (s1_inst[24:20] == 0) |-> (s1_dataB == 0);
endproperty

sb_check: assert property (StypeWmaskNumberofOneSB);

sh_check: assert property (StypeWmaskNumberofOneSH);

sw_check: assert property (StypeWmaskNumberofOneSW);

lb_check: assert property (UpperImmediateLB);

lh_check: assert property (UpperImmediateLH);

zero_A_check: assert property (ZeroRegisterMustBeZeroA);

zero_B_check: assert property (ZeroRegisterMustBeZeroB);

ResetConditionCheck: assert property (ResetCondition);

ResetCover: cover property (@(posedge clk) reset);
SBCover: cover property (@(posedge clk) (s1_inst[14:12] == `FNC_SB && s1_inst[6:0] == `OPC_STORE));
SHCover: cover property (@(posedge clk) (s1_inst[14:12] == `FNC_SH && s1_inst[6:0] == `OPC_STORE));
SWCover: cover property (@(posedge clk) (s1_inst[14:12] == `FNC_SW && s1_inst[6:0] == `OPC_STORE));
LBCover: cover property (@(posedge clk) ((control.s2_inst[6:0] == `OPC_LOAD) && (control.s2_inst[14:12]) == `FNC_LB));
LHCover: cover property (@(posedge clk) ((control.s2_inst[6:0] == `OPC_LOAD) && (control.s2_inst[14:12]) == `FNC_LH));
ZeroACover: cover property (@(posedge clk) (s1_inst[19:15] == 0));
ZeroBCover: cover property (@(posedge clk) (s1_inst[24:20] == 0));