// Casio PV-1000 Core for MiSTer by Flandango

module CasioPV1000
(
	input         clk,
	input         clk_cpu,
	input         clk_vdp,
	input         clk_snd,
	input         reset,
	
	///////////// CPU RAM Interface /////////////
	output [15:0] cpu_ram_a_o,
	output reg    cpu_ram_ce_n_o,
	output reg    cpu_ram_we_n_o,
	input   [7:0] cpu_ram_d_i,
	output  [7:0] cpu_ram_d_o,

	//////////// Joystick Interface /////////////
	
	input [31:0]  joy0,
	input [31:0]  joy1,

	////////////// AUDIO Interface //////////////
	output [7:0] audio,

	////////////// VIDEO Interface //////////////
	output reg    HBlank,
	output reg    HSync,
	output reg    VBlank,
	output reg    VSync,
	output [15:0] vram_a,
	input   [7:0] vram_di,
	output  [23:0] video
);


reg nMEM;
reg nRD;
reg nWR;
reg nIRQ;
reg nINT;
reg nNMI;
reg nWAIT;

reg [15:0] cpu_addr;
reg [7:0] data_to_cpu;
reg [7:0] data_from_cpu;

cpu_z80 Z80CPU(
	.CLK_4M(clk_cpu),
	.nRESET(~reset),
	.SDA(cpu_addr),
	.SDD_IN(data_to_cpu),
	.SDD_OUT(data_from_cpu),
	.nIORQ(nIRQ),
	.nMREQ(nMEM),
	.nRD(nRD),
	.nWR(nWR),
	.nINT(nINT),
	.nNMI(nNMI),
	.nWAIT(nWAIT)
);

assign cpu_ram_we_n_o = (cpu_ram_a_o > 16'h7FFF && (~nMEM && ~nWR)) ? 1'b0 : 1'b1;
assign cpu_ram_ce_n_o = (~nMEM && !nRD) ? 1'b0 : 1'b1;
assign nWAIT = 1'b1;
assign nNMI = 1'b1;
assign cpu_ram_a_o = cpu_addr;
assign cpu_ram_d_o = data_from_cpu;
assign data_to_cpu = (cpu_addr[7:0] == 8'hFC && nMEM && ~nRD) ? port_status : (cpu_addr[7:0] == 8'hFD && nMEM && ~nRD) ? io_data : cpu_ram_d_i;

///////////////////////////SOUND///////////////////////////

reg  [10:0] counter;
reg  [5:0]  tone_0_period, tone_1_period, tone_2_period;
reg         tone_0, tone_1, tone_2;
reg  [1:0]  snd_sum;
reg  [7:0] sound_channel[3];

always @(posedge clk_snd) begin
	if(reset) begin
		tone_0_period <= 6'd0;
		tone_1_period <= 6'd0;
		tone_2_period <= 6'd0;
	end
	else begin
		counter <= counter + 1'b1;
		if(counter == 11'd512) begin
			counter <= 11'd0;
			tone_0_period <= tone_0_period + 1'b1;
			tone_1_period <= tone_1_period + 1'b1;
			tone_2_period <= tone_2_period + 1'b1;
			if(tone_0_period == (6'h3F - sound_channel[0][5:0]) -1) begin
				tone_0_period <= 6'd0;
				tone_0 <= ~tone_0;
			end
			if(tone_1_period == (6'h3F - sound_channel[1][5:0]) -1) begin
				tone_1_period <= 6'd0;
				tone_1 <= ~tone_1;
			end
			if(tone_2_period == (6'h3F - sound_channel[2][5:0]) -1) begin
				tone_2_period <= 6'd0;
				tone_2 <= ~tone_2;
			end
		end
	end
end

assign snd_sum = tone_0 + tone_1 + tone_2;
assign audio = {snd_sum,6'd0};


/////////////////////////// IO ///////////////////////////

reg [7:0] io_data;
reg [7:0] io_regs[8];
reg [7:0] FD_data;
reg       FD_buffer_flag;
reg [1:0] rd_sampler,wr_sampler;
reg [7:0] port_status;

always @(posedge clk) begin
	rd_sampler = {rd_sampler[0],nRD};
	wr_sampler = {wr_sampler[0],nWR};
end

always @(posedge clk) begin
   if(reset) begin
		FD_data = 8'h00;
		io_regs[5] = 8'h00;
		sound_channel[0] = 8'hFF;
		sound_channel[1] = 8'hFF;
		sound_channel[2] = 8'hFF;
	end
	Y_D <= Y;
	if(Y_D==10'd210 && Y==10'd211) FD_buffer_flag <= 1'b1;

	//IO READS
	if(cpu_ram_a_o[7:0] == 8'hF8 && ~nRD && nMEM) io_data = io_regs[0];
	if(cpu_ram_a_o[7:0] == 8'hF9 && ~nRD && nMEM) io_data = io_regs[1];
	if(cpu_ram_a_o[7:0] == 8'hFA && ~nRD && nMEM) io_data = io_regs[2];
	if(cpu_ram_a_o[7:0] == 8'hFB && ~nRD && nMEM) io_data = io_regs[3];

	if(cpu_ram_a_o[7:0] == 8'hFC && ~nRD && nMEM && rd_sampler == 2'b10) begin
		port_status[0] = FD_buffer_flag;
		port_status[1] = |FD_data;
		port_status[7:2] = 6'd0;
		FD_buffer_flag <= 1'b0;
	end

	if(cpu_ram_a_o[7:0] == 8'hFD && ~nRD && nMEM && rd_sampler == 2'b10) begin
		io_data = 8'h00;
	   if(io_regs[5][0]) begin
			io_data[3:0] = io_data[3:0] | {joy1[7],joy1[6],joy0[7],joy0[6]};
			FD_data[0] = FD_data[0] & 1'b0;
		end
		
	   if(io_regs[5][1]) begin
			io_data[3:0] = io_data[3:0] | {joy1[0],joy1[2],joy0[0],joy0[2]};
			FD_data[1] = FD_data[1] & 1'b0;
		end
		
	   if(io_regs[5][2]) begin
			io_data[3:0] = io_data[3:0] | {joy1[3],joy1[1],joy0[3],joy0[1]};
			FD_data[2] = FD_data[2] & 1'b0;
		end
		
	   if(io_regs[5][3]) begin
			io_data[3:0] = io_data[3:0] | {joy1[4],joy1[5],joy0[4],joy0[5]};
			FD_data[3] = FD_data[3] & 1'b0;
		end
	end
	if(cpu_ram_a_o[7:0] == 8'hFE && ~nRD && nMEM && rd_sampler == 2'b10) io_data = io_regs[6];
	if(cpu_ram_a_o[7:0] == 8'hFF && ~nRD && nMEM && rd_sampler == 2'b10) io_data = io_regs[7];

	//IO WRITES
	if((cpu_ram_a_o[7:0] >= 8'hF8 && cpu_ram_a_o[7:0] <= 8'hFA) && nMEM && wr_sampler == 2'b10) sound_channel[cpu_ram_a_o[1:0]] = data_from_cpu;
	if(cpu_ram_a_o[7:3] == 5'h1F && ~nWR && nMEM && wr_sampler == 2'b10) io_regs[cpu_ram_a_o[2:0]] = data_from_cpu;
	if(cpu_ram_a_o[7:0] == 8'hFD && ~nWR && nMEM && wr_sampler == 2'b10) FD_data = 8'h0F;
	if(cpu_ram_a_o[7:0] == 8'hFF && ~nWR && nMEM && wr_sampler == 2'b10) begin
		force_pattern = data_from_cpu[4];
		pcg_bank = data_from_cpu[5];
		border_color = data_from_cpu[2:0];
	end
end


///////////////////////////VIDEO///////////////////////////


reg   [9:0] X,Y;		//Visibile Display
reg   [9:0] hc,vc;	//Raster Scan
reg   [7:0] tile;

always @(posedge clk) begin
	if(read_tile) tile = vram_di;
end


localparam V_IDLE = 0;
localparam V_GET_TILE = 1;
localparam V_READ_RED = 2;
localparam V_READ_GREEN = 3;
localparam V_READ_BLUE = 4;
localparam V_DONE = 5;


reg [2:0] v_state;
reg [9:0] t_offset, X_D, Y_D;
//reg [9:0] X_D, Y_D;
reg       read_tile, rgb_bit_read;
reg [7:0] RED_r,GREEN_r;
reg [7:0] RED,GREEN,BLUE;

reg       force_pattern;
reg       pcg_bank;
reg [2:0] border_color;

always @(posedge clk) begin
	if((Y >= 10'd0 && Y < 10'd192) && (X >= 10'd0 && X < 10'd256)) begin
		t_offset = (Y/10'd8) * 10'd32 + (X/10'd8);
	end
end

always @(posedge clk) begin
	if(X < 10'd256) X_D <= X;
		
	case(v_state)
	V_IDLE:
	begin
		if(X < 10'd256) begin
			if(X_D != X) begin
				rgb_bit_read = 1;
			end
			else if (rgb_bit_read) begin
				rgb_bit_read = 0;
				vram_a = 16'hB800 + t_offset;
//				vram_a = 16'hB800 + (Y/10'd8) * 10'd32 + (X/10'd8);
				v_state <= V_GET_TILE;
			end
		end
	end
	
	V_GET_TILE:
	begin
		read_tile = 1'b1;
		if(rgb_bit_read) begin
			rgb_bit_read = 0;
			v_state <= V_READ_RED;
		end
		else rgb_bit_read = 1;
	end
	
	V_READ_RED:
	begin
		if(read_tile) read_tile = 1'b0;
		if(tile < 'hE0 || force_pattern) vram_a = (((tile + (pcg_bank ? 16'h100 : 16'h0)) * 8'd32) + (Y%10'd8) + 8'd8);
		else vram_a = 16'hBC00 + (((tile - 8'hE0) * 8'd32) + (Y%10'd8) + 8'd8);
		if(rgb_bit_read) begin
			rgb_bit_read = 0;
			v_state <= V_READ_GREEN;
		end
		else rgb_bit_read = 1;
	end
	
	V_READ_GREEN:
	begin
		RED_r = vram_di[(7-(X%10'd8))] ? 8'hFF : 8'h00;
		if(tile < 'hE0 || force_pattern) vram_a = (((tile + (pcg_bank ? 16'h100 : 16'h0)) * 8'd32) + (Y%10'd8) + 8'd16);
		else vram_a = 16'hBC00 + (((tile - 8'hE0) * 8'd32) + (Y%10'd8) + 8'd16);
		if(rgb_bit_read) begin
			rgb_bit_read = 0;
			v_state <= V_READ_BLUE;
		end
		else rgb_bit_read = 1;
	end

	V_READ_BLUE:
	begin
		GREEN_r = vram_di[(7-(X%10'd8))] ? 8'hFF : 8'h00;
		if(tile < 'hE0 || force_pattern) vram_a = (((tile + (pcg_bank ? 16'h100 : 16'h0)) * 8'd32) + (Y%10'd8) + 8'd24);
		else vram_a = 16'hBC00 + (((tile - 8'hE0) * 8'd32) + (Y%10'd8) + 8'd24);
		if(rgb_bit_read) begin
			rgb_bit_read = 0;
			v_state <= V_DONE;
		end
		else rgb_bit_read = 1;
	end

	V_DONE:
	begin
		BLUE = vram_di[(7-(X%10'd8))] ? 8'hFF : 8'h00;
		RED = RED_r;
		GREEN = GREEN_r;
		v_state <= V_IDLE;
	end

	default: ;
	
	endcase
end

always @(posedge clk_vdp) begin
	if((Y == 195 || Y == 199 || Y == 203 || Y == 207 || Y == 211 ||
   	Y == 215 || Y == 219 || Y == 223 || Y == 227 || Y == 231 || 
		Y == 235 || Y == 239 || Y == 243 || Y == 247 || Y == 251 || 
		Y == 255) && (X >=0 && X<=190)) nINT <= 1'b0;
	else nINT <= 1'b1;

end

always @(posedge clk_vdp) begin
	if(reset) begin
		hc <= 0;
		vc <= 0;
	end
	else begin
		if(hc == 380) begin
			hc <= 0;
			if(vc == 262) begin 
				vc <= 0;
			end else begin
				vc <= vc + 1'd1;
			end
		end else begin
			hc <= hc + 1'd1;
		end
	end
end

always @(posedge clk_vdp) begin
	if (hc == 239) HBlank <= 1; 
		else if (hc == 16) HBlank <= 0;

	if (hc == 341) begin
		HSync <= 1;
		if(vc == 259) VSync <= 1;
			else if (vc == 262) VSync <= 0;

		if(vc == 223) VBlank <= 1;
			else if (vc == 262) VBlank <= 0;
	end
	
	if (hc == 360) HSync <= 0;
end

assign X = hc;
assign Y = vc - 10'd16;
assign video = (Y >= 10'd0 && Y < 10'd192) ? {RED,GREEN,BLUE} : {border_color[0] * 8'hFF, border_color[1] * 8'hFF, border_color[2] * 8'hFF} ;

endmodule
