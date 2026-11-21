`timescale 1ns / 1ps
// Five-stage educational MIPS pipeline: IF, ID, EX, MEM, WB.
// Instructions supported: R-type ADD/SUB/AND/OR/SLT, LW, SW, BEQ.
// No data hazard forwarding/stalling. The supplied program inserts spacing.
// For this assignment, data-memory addresses are WORD INDICES (offsets 1,2,3).
module mips_pipeline(input wire clk, input wire rst);
    reg [31:0] pc;
    reg [31:0] instr_mem [0:255];
    reg [31:0] data_mem  [0:255];
    reg [31:0] regfile   [0:31];

    // IF: instruction fetch and IF/ID pipeline latch.
    wire [31:0] instruction = instr_mem[pc[9:2]];
    wire [31:0] pc_plus4 = pc + 32'd4;
    reg [31:0] ifid_instruction, ifid_pc4;

    // ID: decode and register file reads.
    wire [5:0] opcode = ifid_instruction[31:26];
    wire [4:0] rs = ifid_instruction[25:21];
    wire [4:0] rt = ifid_instruction[20:16];
    wire [4:0] rd = ifid_instruction[15:11];
    wire [5:0] funct = ifid_instruction[5:0];
    wire [31:0] immediate = {{16{ifid_instruction[15]}}, ifid_instruction[15:0]};
    wire [31:0] reg_a = (rs == 0) ? 32'b0 : regfile[rs];
    wire [31:0] reg_b = (rt == 0) ? 32'b0 : regfile[rt];
    reg ctl_regwrite, ctl_memtoreg, ctl_memwrite, ctl_branch, ctl_alusrc, ctl_regdst;
    reg [2:0] ctl_alu;

    always @* begin
        ctl_regwrite = 0;
        ctl_memtoreg = 0;
        ctl_memwrite = 0;
        ctl_branch = 0;
        ctl_alusrc = 0;
        ctl_regdst = 0;
        ctl_alu = 3'b010; // default ADD
        case (opcode)
            6'b000000: begin // R type; only recognized functions change state
                case (funct)
                    6'h20: begin ctl_regwrite=1; ctl_regdst=1; ctl_alu=3'b010; end // add
                    6'h22: begin ctl_regwrite=1; ctl_regdst=1; ctl_alu=3'b110; end // sub
                    6'h24: begin ctl_regwrite=1; ctl_regdst=1; ctl_alu=3'b000; end // and
                    6'h25: begin ctl_regwrite=1; ctl_regdst=1; ctl_alu=3'b001; end // or
                    6'h2a: begin ctl_regwrite=1; ctl_regdst=1; ctl_alu=3'b111; end // slt
                    default: begin end
                endcase
            end
            6'h23: begin // lw
                ctl_regwrite=1; ctl_memtoreg=1; ctl_alusrc=1;
            end
            6'h2b: begin // sw
                ctl_memwrite=1; ctl_alusrc=1;
            end
            6'h04: begin // beq
                ctl_branch=1; ctl_alu=3'b110;
            end
            default: begin end // unspecified opcodes perform no state changes
        endcase
    end

    // ID/EX pipeline latch.
    reg [31:0] idex_pc4, idex_a, idex_b, idex_imm;
    reg [4:0] idex_rt, idex_rd;
    reg idex_regwrite, idex_memtoreg, idex_memwrite, idex_branch;
    reg idex_alusrc, idex_regdst;
    reg [2:0] idex_alu;

    // EX: ALU, branch target, destination-register selection.
    wire [31:0] alu_b = idex_alusrc ? idex_imm : idex_b;
    reg [31:0] alu_result;
    always @* begin
        case (idex_alu)
            3'b000: alu_result = idex_a & alu_b;
            3'b001: alu_result = idex_a | alu_b;
            3'b010: alu_result = idex_a + alu_b;
            3'b110: alu_result = idex_a - alu_b;
            3'b111: alu_result = ($signed(idex_a) < $signed(alu_b)) ? 32'd1 : 32'd0;
            default: alu_result = 0;
        endcase
    end
    wire [31:0] ex_branch_target = idex_pc4 + (idex_imm << 2);
    wire [4:0] ex_dest = idex_regdst ? idex_rd : idex_rt;

    // EX/MEM pipeline latch.
    reg [31:0] exmem_alu, exmem_store_data, exmem_branch_target;
    reg [4:0] exmem_dest;
    reg exmem_zero, exmem_branch, exmem_regwrite, exmem_memtoreg, exmem_memwrite;

    // MEM: data-memory access, and branch decision (from EX/MEM).
    wire pcsrc = exmem_branch && exmem_zero;
    wire [31:0] mem_read_data = data_mem[exmem_alu[7:0]];

    // MEM/WB pipeline latch.
    reg [31:0] memwb_read_data, memwb_alu;
    reg [4:0] memwb_dest;
    reg memwb_regwrite, memwb_memtoreg;

    // WB: select result and write register file.
    wire [31:0] wb_value = memwb_memtoreg ? memwb_read_data : memwb_alu;

    integer i;
    initial begin
        pc = 0;
        ifid_instruction = 0; ifid_pc4 = 0;
        idex_pc4=0; idex_a=0; idex_b=0; idex_imm=0;
        idex_rt=0; idex_rd=0; idex_regwrite=0; idex_memtoreg=0;
        idex_memwrite=0; idex_branch=0; idex_alusrc=0; idex_regdst=0; idex_alu=0;
        exmem_alu=0; exmem_store_data=0; exmem_branch_target=0;
        exmem_dest=0; exmem_zero=0; exmem_branch=0;
        exmem_regwrite=0; exmem_memtoreg=0; exmem_memwrite=0;
        memwb_read_data=0; memwb_alu=0; memwb_dest=0;
        memwb_regwrite=0; memwb_memtoreg=0;
        for (i=0; i<256; i=i+1) begin
            instr_mem[i] = 32'b0;
            data_mem[i] = 32'b0;
        end
        for (i=0; i<32; i=i+1) regfile[i] = 32'b0;
        $readmemb("instr.mem", instr_mem);
        $readmemb("data.mem", data_mem);
    end

    always @(posedge clk) begin
        if (rst) begin
            pc <= 0;
            ifid_instruction <= 0; ifid_pc4 <= 0;
            idex_pc4<=0; idex_a<=0; idex_b<=0; idex_imm<=0;
            idex_rt<=0; idex_rd<=0; idex_regwrite<=0; idex_memtoreg<=0;
            idex_memwrite<=0; idex_branch<=0; idex_alusrc<=0; idex_regdst<=0; idex_alu<=0;
            exmem_alu<=0; exmem_store_data<=0; exmem_branch_target<=0;
            exmem_dest<=0; exmem_zero<=0; exmem_branch<=0;
            exmem_regwrite<=0; exmem_memtoreg<=0; exmem_memwrite<=0;
            memwb_read_data<=0; memwb_alu<=0; memwb_dest<=0;
            memwb_regwrite<=0; memwb_memtoreg<=0;
            for (i=0; i<32; i=i+1) regfile[i] <= 0;
        end else begin
            // WB (the current MEM/WB stage)
            if (memwb_regwrite && memwb_dest != 0)
                regfile[memwb_dest] <= wb_value;
            // MEM: commit store; forward load and ALU results into MEM/WB
            if (exmem_memwrite) data_mem[exmem_alu[7:0]] <= exmem_store_data;
            memwb_read_data <= mem_read_data;
            memwb_alu <= exmem_alu;
            memwb_dest <= exmem_dest;
            memwb_regwrite <= exmem_regwrite;
            memwb_memtoreg <= exmem_memtoreg;
            // EX/MEM: flush younger EX instruction when MEM resolves a branch
            exmem_alu <= alu_result;
            exmem_store_data <= idex_b;
            exmem_branch_target <= ex_branch_target;
            exmem_zero <= (alu_result == 0);
            exmem_dest <= ex_dest;
            exmem_branch <= pcsrc ? 0 : idex_branch;
            exmem_regwrite <= pcsrc ? 0 : idex_regwrite;
            exmem_memtoreg <= pcsrc ? 0 : idex_memtoreg;
            exmem_memwrite <= pcsrc ? 0 : idex_memwrite;
            // ID/EX: flush younger ID instruction on taken branch
            idex_pc4 <= ifid_pc4;
            idex_a <= reg_a;
            idex_b <= reg_b;
            idex_imm <= immediate;
            idex_rt <= rt;
            idex_rd <= rd;
            idex_regwrite <= pcsrc ? 0 : ctl_regwrite;
            idex_memtoreg <= pcsrc ? 0 : ctl_memtoreg;
            idex_memwrite <= pcsrc ? 0 : ctl_memwrite;
            idex_branch <= pcsrc ? 0 : ctl_branch;
            idex_alusrc <= ctl_alusrc;
            idex_regdst <= ctl_regdst;
            idex_alu <= ctl_alu;
            // IF and IF/ID. Flush fetched instruction on taken branch.
            pc <= pcsrc ? exmem_branch_target : pc_plus4;
            ifid_instruction <= pcsrc ? 32'b0 : instruction;
            ifid_pc4 <= pcsrc ? 32'b0 : pc_plus4;
        end
    end
endmodule
