// Module: s1_BRANCH_COMP 
// Desc:   The Branch Comparator
// Inputs: s1_dataA: the first operand
//         s1_dataB: the second operand
//         BrUn: Whether the comparison is unsigned or not
// Outputs: BrEq: Whether the two operands are equal
//          BrLt: Whether the first operand is less than the second
//

`include "const.vh"
module s1_BRANCH_COMP(
    input [`CPU_DATA_BITS-1: 0] s1_dataA,
    input [`CPU_DATA_BITS-1: 0] s1_dataB,
    input BrUn,
    output BrEq,
    output BrLt
);

    assign BrEq = (s1_dataA == s1_dataB);
    assign BrLt = (BrUn == 1'b1) ? (s1_dataA < s1_dataB) : ($signed(s1_dataA) < $signed(s1_dataB));
    
endmodule