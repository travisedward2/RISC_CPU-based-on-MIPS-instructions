// Please include verilog file if you write module in other file
module CPU(
    input             clk,
    input             rst,
    input      [31:0] data_out,
    input      [31:0] instr_out,


    output reg        instr_read,
    output reg        data_read,
    output reg [31:0] instr_addr,
    output reg [31:0] data_addr,
    output reg [3:0]  data_write,
    output reg [31:0] data_in
);
//R TYPE 指令 MIX I TYPE 指令
reg [6:0] opcode;
reg [4:0] rd,rs1,rs2;
reg [2:0] funct3;
reg [6:0] funct7;
reg [4:0] shamt;
//

reg [31:0] temp_inst_out;
reg [31:0] temp_data_out;
 
parameter READ_INS=3'b000,
		  GET_INS=3'b001,
		  SAVE_INST=3'b010,
		  DECODE=3'b011,

		  GET_DATA=3'b100,
		  SAVE_DATA=3'b101,
		  LOAD_DATA=3'b110;



reg [2:0] State;
reg [31:0] pc;
reg [31:0] x[31:0];
reg [31:0] imm;
reg [31:0] t_rs1;
reg [31:0] t_rs2;
reg [31:0] t_rd;
reg [31:0] ALU;
reg [31:0] signal;
reg [31:0] j_temp;
 
integer index=0;



//當你的CPU說要讀取某ADDRESS的指令時，下課POSEDGE CLK才會傳進來
//最重要的問題就是，到底哪時候要把下個instruction讀進來?
//data的處理又有沒有要用到DM?
//心得: 做完就可以去讀下一個INSTRUCTION了
always @(posedge clk or posedge rst) begin
//試著讀取instruction
//先將rst的事情做好
// rst是初始化
	if (rst== 1'b1) begin
	pc =32'h0;
	instr_addr =32'h0;
	instr_read =1'bz;
	data_read =1'bz;
	data_addr =32'hz;
	data_write =4'hz;
	data_in =32'hz;
	for(index=0;index<32;index=index+1)
		x[index] =32'h0;
	State =READ_INS;
	end
//初始化結束，開始處理
	else begin
		case(State)
		READ_INS:
		begin
			
			
			//去讀IM中的指令
			instr_addr =pc;
			instr_read =1'b1;
			State =GET_INS;


			//在每次準備執行下一個指令時，將該斷掉的訊號斷掉
			j_temp=32'hz;
			opcode =7'bz;
			temp_inst_out =32'hz;
			temp_data_out =32'hz;
			funct3 =3'bz;
			funct7 =7'bz;
			shamt =5'bz;
			rs2 =5'bz;
			rs1 =5'bz;
			rd =5'bz;
			imm =32'bz;
			data_in =32'bz;
			data_read =1'bz;
			data_addr =32'bz;
			data_write =4'bz;
			t_rd =32'hz;
			t_rs1 =32'hz;
			t_rs2 =32'hz;
			ALU=32'hz;
			signal=32'hz;
				
		end
		GET_INS:
		begin

			State =SAVE_INST;

			instr_read =1'b0;
		end //GET_INS END

		SAVE_INST://確認此次要處理的instruction
		begin
		    temp_inst_out =instr_out;
			x[0] =32'h0;//在執行每個指令時確保$zero的沒被上個指令亂改到
			State =DECODE;
		end //SAVE_INST END

		DECODE://處理instruction

		begin

			opcode =temp_inst_out[6:0];

			case(opcode)//opcode case

			7'b0110011://R-TYPE INSTRUCTION
			begin
				State =READ_INS;
				pc =pc+32'h4;
				//先parse instruction to R TYPE FORMAT
				{funct7,rs2,rs1,funct3,rd} =temp_inst_out[31:7];
				
				case({funct7,funct3})
					10'b0000000000: x[rd] = x[rs1] + x[rs2];	//ADD
					10'b0100000000: x[rd] = x[rs1] - x[rs2];	//SUB
					10'b0000000001: x[rd] = $unsigned(x[rs1]) << x[rs2][4:0];	//SLL
					10'b0000000010: x[rd] = ($signed(x[rs1]) < $signed(x[rs2])) ? 32'd1 : 32'd0;	//SLT
					10'b0000000011: x[rd] = ($unsigned(x[rs1]) < $unsigned(x[rs2])) ? 32'd1 : 32'd0;	//SLTU
					10'b0000000100: x[rd] = x[rs1] ^ x[rs2];	//XOR
					10'b0000000101: x[rd] = $unsigned(x[rs1]) >> x[rs2][4:0];	//SRL
					10'b0100000101: x[rd] = $signed(x[rs1]) >> x[rs2][4:0];	//SRA
					10'b0000000110: x[rd] = x[rs1] | x[rs2];	//OR
					10'b0000000111: x[rd] = x[rs1] & x[rs2];	//AND
				endcase
				t_rd = x[rd];
				t_rs1 = x[rs1];
				t_rs2 =x[rs2];

			end//R-TYPE INSTUCTION END

			7'b0000011://I-TYPE USING MEMORIES
			begin
				State = GET_DATA;
				//下個state data的資料才會輸進來
				//這邊先處理instruction parse 和 data require
				{rs1,funct3,rd}=temp_inst_out[19:7];
				imm={{20{temp_inst_out[31]}},temp_inst_out[31:20]};
				data_read=1;
				data_addr=x[rs1]+imm;

			end//I-TYPE USING MEMORIES



			7'b0010011://I-TYPE CALCULATING
			begin

				State=READ_INS;//下個state要去請下一個instruction
				pc=pc+4;
				
				// 先parse instruction_out

				shamt=temp_inst_out[24:20];
				{rs1,funct3,rd}=temp_inst_out[19:7];
				imm={{20{temp_inst_out[31]}},temp_inst_out[31:20]};
			

				case(funct3)
				
				3'b000://ADDI
				begin
					x[rd]=x[rs1]+imm;	
					//ALU=x[rd];
	
				end	

				3'b010://SLTI	
				begin
					x[rd]=(($signed(x[rs1]))<$signed(imm)) ? 32'h1 : 32'h0;

				end

				3'b011://SLTIU
				begin
					x[rd] = ($unsigned(x[rs1]) < $unsigned(imm)) ? 32'h1 : 32'h0;
				end

				3'b100://XORI
				begin
					x[rd] = x[rs1] ^ imm;
				end

				3'b110://ORI
				begin
					x[rd] = x[rs1] | imm;
				end

				3'b111://ANDI
				begin
					x[rd] = x[rs1] & imm;
				end

				3'b001://SLLI
				begin
					x[rd] = $unsigned(x[rs1]) << shamt;
				end

				3'b101:
				begin
					if (temp_inst_out[31:25]==7'b0000000) 
					begin
						x[rd] = $unsigned(x[rs1]) >> shamt;	//SRLI
					end
					else 
					begin
						x[rd] = $signed(x[rs1]) >>> shamt; //SRAI
					end
				end

				default:
				begin
				pc =32'h0;
				end

				endcase//funct3

				t_rd =x[rd];
				t_rs1 =x[rs1];
				
			end//I-TYPE CALCULATING


			7'b1100011://B-TYPE
			begin
				State =READ_INS;
				{rs2, rs1, funct3} = temp_inst_out[24:12];
				imm = {{19{temp_inst_out[31]}}, temp_inst_out[31], temp_inst_out[7], temp_inst_out[30:25], temp_inst_out[11:8], 1'b0};
				case(funct3)
							3'b000: pc = (x[rs1] == x[rs2]) ? (pc + imm) : (pc + 32'h4);	//BEQ
							3'b001: pc = (x[rs1] != x[rs2]) ? (pc + imm) : (pc + 32'h4);	//BNE
							3'b100: pc = ($signed(x[rs1]) < $signed(x[rs2])) ? (pc + imm) : (pc + 32'h4);	//BLT
							3'b101: pc = ($signed(x[rs1]) >= $signed(x[rs2])) ? (pc + imm) : (pc + 32'h4);	//BGE
							3'b110: pc = ($unsigned(x[rs1]) < $unsigned(x[rs2])) ? (pc + imm) : (pc + 32'h4);	//BLTU
							3'b111: pc = ($unsigned(x[rs1]) >= $unsigned(x[rs2])) ? (pc + imm) : (pc + 32'h4);	//BGEU
				endcase

				t_rs1 =x[rs1];
				t_rs2 =x[rs2];
			end//B-TYPE

			7'b0010111:	//AUIPC
			begin

				
				State =READ_INS;
				imm = {temp_inst_out[31:12], 12'b0};
				rd = temp_inst_out[11:7];
				x[rd] =pc+imm;
				t_rd =x[rd];
				pc =pc+32'h4;
			
			
			end

			7'b0110111:	//LUI
			begin
				pc =pc+32'h4;
				State =READ_INS;
				imm = {temp_inst_out[31:12], 12'b0};
				rd = temp_inst_out[11:7];
				x[rd]=imm;
				t_rd=x[rd];
		
			end


			7'b1101111://J-TYPE
			begin
				State =READ_INS;
				rd = temp_inst_out[11:7];
				imm = {{11{temp_inst_out[31]}}, temp_inst_out[31], temp_inst_out[19:12], temp_inst_out[20], temp_inst_out[30:21], 1'b0};
				x[rd] =pc+32'h4;
				pc =pc+imm;
				t_rd =x[rd];
			
			end

			7'b1100111://JALR
			begin
				State =READ_INS;
				{rs1, funct3, rd} = temp_inst_out[19:7];
				imm = {{20{temp_inst_out[31]}}, temp_inst_out[31:20]};
				j_temp=x[rd];
				x[rd] =pc+32'h4;
				signal=pc;
				pc=(rd==rs1)?(imm+j_temp):(imm+x[rs1]);
			
			end

			7'b0100011://S-TYPE
			begin
				State =READ_INS;
				pc =pc+32'h4;
				{rs2, rs1, funct3} = temp_inst_out[24:12];
				imm = {{20{temp_inst_out[31]}}, temp_inst_out[31:25], temp_inst_out[11:7]};
				data_addr =x[rs1]+imm;
				data_in =x[rs2];
				case(funct3)
					3'b010:
					begin
						data_write =4'b1111;
					end

					3'b000:
					begin
						case(imm[1:0])
						2'b00:
						begin

							data_write=4'b0001;	
						end
						
						2'b01:
						begin
							data_in={16'b0,data_in[7:0],8'b0};
							data_write=4'b0010;
						end
					
						2'b10:
						begin
							data_in={8'b0,data_in[7:0],16'b0};
							data_write=4'b0100;
						end
						
						2'b11:
						begin
							data_in={data_in[7:0],24'b0};
							data_write=4'b1000;
						end
						
						endcase
					end

					3'b001:
					begin
						case(imm[1])
						1'b0:
						begin
							data_in={16'b0,data_in[15:0]};
							data_write=4'b0011;
						end
					
						1'b1:
						begin
							data_in={data_in[15:0],16'b0};
							data_write=4'b1100;
						end
					
						endcase
					end

					default:
						data_write =4'hx;

				endcase
						
			end




			endcase//opcode case end (instruction without using DM ends here)
					ALU=x[5];
		//pc=pc+4;//寫完以後這行要刪掉!
		//temp=x[rd];	
		//State=READ_INS;
		end // DECODE 完成


		
		GET_DATA:
		begin
			State =SAVE_DATA;
			data_read=1'b0;
		end

		SAVE_DATA:
		begin
			temp_data_out=data_out;
			State=LOAD_DATA;
		end

		LOAD_DATA:
		begin
			State=READ_INS;
			pc=pc+32'h4;
			case(funct3)
				3'b010:
				begin
					x[rd]=temp_data_out;
				end
				
				3'b000:
				begin
					x[rd]={{24{temp_data_out[7]}},temp_data_out[7:0]};
				end

				3'b001:
				begin
					x[rd]={{16{temp_data_out[15]}},temp_data_out[15:0]};
				end

				3'b100:
				begin
					x[rd]={24'h000000,temp_data_out[7:0]};
				end

				3'b101:
				begin
					x[rd]={16'h0000,temp_data_out[15:0]};
				end

				default: 
					x[rd]=32'hz;

			endcase
		end

		default:
		begin
		 	pc=32'hz;	
		end	

		endcase	//endcase of case(State)		
	end
		
end


endmodule
