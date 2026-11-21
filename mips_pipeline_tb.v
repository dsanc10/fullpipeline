`timescale 1ns / 1ps
module mips_pipeline_tb;
    reg clk;
    reg rst;
    mips_pipeline uut (.clk(clk), .rst(rst));
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 ns clock period
    end
    initial begin
        rst = 1;
        #10 rst = 0;
        #1000;
        if (uut.regfile[1] === 32'd12)
            $display("PASS: register $1 = %0d", uut.regfile[1]);
        else
            $display("FAIL: register $1 = %0d; expected 12", uut.regfile[1]);
        $finish;
    end
    always @(posedge clk) begin
        #1;
        if (!rst)
            $display("time=%0t PC=%h IF/ID=%h EX=%h MEM=%h WB=%h R1=%0d R2=%0d R3=%0d",
                $time, uut.pc, uut.ifid_instruction, uut.alu_result,
                uut.exmem_alu, uut.wb_value,
                uut.regfile[1], uut.regfile[2], uut.regfile[3]);
    end
endmodule
