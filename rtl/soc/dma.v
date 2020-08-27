/*
 * Copyright (c) 2014, Aleksander Osman
 * Copyright (C) 2017-2020 Alexey Melnikov
 * All rights reserved.
 * 
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 * 
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

module dma
(
	input               clk,
	input               rst_n,


	input       [4:0]   io_address,
	input               io_read,
	output reg  [7:0]   io_readdata,
	input               io_write,
	input       [7:0]   io_writedata,

	input               io_master_cs, //0C0h - 0DFh for master DMA 
	input               io_slave_cs,  //000h - 00Fh for slave DMA
	input               io_page_cs,   //080h - 08Fh for DMA page    

	//master
	output reg  [23:0]  avm_address,
	output reg          avm_16bit,
	input               avm_waitrequest,
	output reg          avm_read,
	input               avm_readdatavalid,
	input      [15:0]   avm_readdata,
	output reg          avm_write,
	output reg [15:0]   avm_writedata,

	//floppy 8-bit dma channel
	input               dma_2_req,
	output reg          dma_2_ack,
	output reg          dma_2_terminal,
	output reg  [7:0]   dma_2_readdata,
	input       [7:0]   dma_2_writedata,

	//soundblaster 8-bit dma channel
	input               dma_1_req,
	output reg          dma_1_ack,
	output reg          dma_1_terminal,
	output reg  [7:0]   dma_1_readdata,
	input       [7:0]   dma_1_writedata,

	//soundblaster 16-bit dma channel
	input               dma_5_req,
	output reg          dma_5_ack,
	output reg          dma_5_terminal,
	output reg [15:0]   dma_5_readdata,
	input      [15:0]   dma_5_writedata
);

wire master_read  = io_read  & io_master_cs;
wire master_write = io_write & io_master_cs;
wire slave_read   = io_read  & io_slave_cs;
wire slave_write  = io_write & io_slave_cs;
wire page_write   = io_write & io_page_cs;

always @(posedge clk) begin
    if(io_master_cs)      io_readdata <= mas_readdata_prepared;
    else if(io_slave_cs)  io_readdata <= sla_readdata_prepared;
    else                  io_readdata <= pag_readdata_prepared;
end

reg slave_read_last;
always @(posedge clk) begin if(rst_n == 1'b0) slave_read_last <= 1'b0; else if(slave_read_last) slave_read_last <= 1'b0; else slave_read_last <= slave_read; end 
wire slave_read_valid = slave_read && slave_read_last == 1'b0;

//not needed: reg page_read_last;

reg master_read_last;
always @(posedge clk) begin if(rst_n == 1'b0) master_read_last <= 1'b0; else if(master_read_last) master_read_last <= 1'b0; else master_read_last <= master_read; end 
wire master_read_valid = master_read && master_read_last == 1'b0;

//------------------------------------------------------------------------------

wire pag_extra_0_address =
    io_address[3:0] == 4'h0 || io_address[3:0] == 4'h4 || io_address[3:0] == 4'h5 || io_address[3:0] == 4'h6 ||
    io_address[3:0] == 4'h8 || io_address[3:0] == 4'hC || io_address[3:0] == 4'hD || io_address[3:0] == 4'hE;

reg [7:0] pag_extra_0;
always @(posedge clk) begin
    if(rst_n == 1'b0)                           pag_extra_0 <= 8'd0;
    else if(page_write && pag_extra_0_address)  pag_extra_0 <= io_writedata;
end

wire [7:0] pag_readdata_prepared =
    (io_address[3:0] == 4'h1) ? sla_page_2 :
    (io_address[3:0] == 4'h2) ? sla_page_3 :
    (io_address[3:0] == 4'h3) ? sla_page_1 :
    (io_address[3:0] == 4'h7) ? sla_page_0 :
    (io_address[3:0] == 4'h9) ? mas_page_2 :
    (io_address[3:0] == 4'hA) ? mas_page_3 :
    (io_address[3:0] == 4'hB) ? mas_page_1 :
    (io_address[3:0] == 4'hF) ? mas_page_0 :
                                pag_extra_0;
                                   
//------------------------------------------------------------------------------

reg [7:0] sla_page_0;
reg [7:0] sla_page_1;
reg [7:0] sla_page_2;
reg [7:0] sla_page_3;

always @(posedge clk) begin if(rst_n == 1'b0) sla_page_0 <= 8'd0; else if(page_write && io_address[3:0] == 4'h7) sla_page_0 <= io_writedata; end
always @(posedge clk) begin if(rst_n == 1'b0) sla_page_1 <= 8'd0; else if(page_write && io_address[3:0] == 4'h3) sla_page_1 <= io_writedata; end
always @(posedge clk) begin if(rst_n == 1'b0) sla_page_2 <= 8'd0; else if(page_write && io_address[3:0] == 4'h1) sla_page_2 <= io_writedata; end
always @(posedge clk) begin if(rst_n == 1'b0) sla_page_3 <= 8'd0; else if(page_write && io_address[3:0] == 4'h2) sla_page_3 <= io_writedata; end

reg [7:0] mas_page_0;
reg [7:0] mas_page_1;
reg [7:0] mas_page_2;
reg [7:0] mas_page_3;

always @(posedge clk) begin if(rst_n == 1'b0) mas_page_0 <= 8'd0; else if(page_write && io_address[3:0] == 4'hF) mas_page_0 <= io_writedata; end
always @(posedge clk) begin if(rst_n == 1'b0) mas_page_1 <= 8'd0; else if(page_write && io_address[3:0] == 4'hB) mas_page_1 <= io_writedata; end
always @(posedge clk) begin if(rst_n == 1'b0) mas_page_2 <= 8'd0; else if(page_write && io_address[3:0] == 4'h9) mas_page_2 <= io_writedata; end
always @(posedge clk) begin if(rst_n == 1'b0) mas_page_3 <= 8'd0; else if(page_write && io_address[3:0] == 4'hA) mas_page_3 <= io_writedata; end

    
//------------------------------------------------------------------------------

wire [7:0] sla_readdata_prepared =
    (io_address[3:0] == 4'h0 && sla_flip_flop == 1'b0) ? sla_current_address_0[7:0] :
    (io_address[3:0] == 4'h0 && sla_flip_flop == 1'b1) ? sla_current_address_0[15:8] :
    (io_address[3:0] == 4'h2 && sla_flip_flop == 1'b0) ? sla_current_address_1[7:0] :
    (io_address[3:0] == 4'h2 && sla_flip_flop == 1'b1) ? sla_current_address_1[15:8] :
    (io_address[3:0] == 4'h4 && sla_flip_flop == 1'b0) ? sla_current_address_2[7:0] :
    (io_address[3:0] == 4'h4 && sla_flip_flop == 1'b1) ? sla_current_address_2[15:8] :
    (io_address[3:0] == 4'h6 && sla_flip_flop == 1'b0) ? sla_current_address_3[7:0] :
    (io_address[3:0] == 4'h6 && sla_flip_flop == 1'b1) ? sla_current_address_3[15:8] :
    
    (io_address[3:0] == 4'h1 && sla_flip_flop == 1'b0) ? sla_current_counter_0[7:0] :
    (io_address[3:0] == 4'h1 && sla_flip_flop == 1'b1) ? sla_current_counter_0[15:8] :
    (io_address[3:0] == 4'h3 && sla_flip_flop == 1'b0) ? sla_current_counter_1[7:0] :
    (io_address[3:0] == 4'h3 && sla_flip_flop == 1'b1) ? sla_current_counter_1[15:8] :
    (io_address[3:0] == 4'h5 && sla_flip_flop == 1'b0) ? sla_current_counter_2[7:0] :
    (io_address[3:0] == 4'h5 && sla_flip_flop == 1'b1) ? sla_current_counter_2[15:8] :
    (io_address[3:0] == 4'h7 && sla_flip_flop == 1'b0) ? sla_current_counter_3[7:0] :
    (io_address[3:0] == 4'h7 && sla_flip_flop == 1'b1) ? sla_current_counter_3[15:8] :

    (io_address[3:0] == 4'h8) ?                        { sla_pending, sla_terminated } :
    (io_address[3:0] == 4'hF) ?                        { 4'hF, sla_mask } :
                                                         8'd0; //temp reg

wire sla_reset = slave_write && io_address[3:0] == 4'hD;

wire sla_flop_flop_flip = (slave_read_valid || slave_write) && (io_address[3:0] <= 4'h7);

reg sla_flip_flop;
always @(posedge clk) begin
    if(rst_n == 1'b0)                               sla_flip_flop <= 1'b0;
    else if(sla_reset)                              sla_flip_flop <= 1'b0;
    else if(slave_write && io_address[3:0] == 4'hC) sla_flip_flop <= 1'b0;
    else if(sla_flop_flop_flip)                     sla_flip_flop <= ~(sla_flip_flop);
end

reg [15:0] sla_base_address_1;
reg [15:0] sla_base_address_2;

always @(posedge clk) begin
    if(rst_n == 1'b0) sla_base_address_1 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h2 && sla_flip_flop == 1'b0)  sla_base_address_1 <= { sla_base_address_1[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h2 && sla_flip_flop == 1'b1)  sla_base_address_1 <= { io_writedata, sla_base_address_1[7:0] };
end
always @(posedge clk) begin
    if(rst_n == 1'b0) sla_base_address_2 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h4 && sla_flip_flop == 1'b0)  sla_base_address_2 <= { sla_base_address_2[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h4 && sla_flip_flop == 1'b1)  sla_base_address_2 <= { io_writedata, sla_base_address_2[7:0] };
end

reg [15:0] sla_current_address_0;
reg [15:0] sla_current_address_1;
reg [15:0] sla_current_address_2;
reg [15:0] sla_current_address_3;

always @(posedge clk) begin
    if(rst_n == 1'b0) sla_current_address_0 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h0 && sla_flip_flop == 1'b0)  sla_current_address_0 <= { sla_current_address_0[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h0 && sla_flip_flop == 1'b1)  sla_current_address_0 <= { io_writedata, sla_current_address_0[7:0] };
end
always @(posedge clk) begin
    if(rst_n == 1'b0) sla_current_address_1 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h2 && sla_flip_flop == 1'b0)  sla_current_address_1 <= { sla_current_address_1[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h2 && sla_flip_flop == 1'b1)  sla_current_address_1 <= { io_writedata, sla_current_address_1[7:0] };

    else if(dma_1_tc && sla_auto_1)                                           sla_current_address_1 <= sla_base_address_1;     
    else if(dma_1_update && ~sla_decrement_1)                                 sla_current_address_1 <= sla_current_address_1 + 16'd1;
    else if(dma_1_update &&  sla_decrement_1)                                 sla_current_address_1 <= sla_current_address_1 - 16'd1;
end
always @(posedge clk) begin
    if(rst_n == 1'b0) sla_current_address_2 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h4 && sla_flip_flop == 1'b0)  sla_current_address_2 <= { sla_current_address_2[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h4 && sla_flip_flop == 1'b1)  sla_current_address_2 <= { io_writedata, sla_current_address_2[7:0] };
    
    else if(dma_2_tc && sla_auto_2)                                           sla_current_address_2 <= sla_base_address_2;

    else if(dma_2_update && ~sla_decrement_2)                                 sla_current_address_2 <= sla_current_address_2 + 16'd1;
    else if(dma_2_update &&  sla_decrement_2)                                 sla_current_address_2 <= sla_current_address_2 - 16'd1;
end
always @(posedge clk) begin
    if(rst_n == 1'b0) sla_current_address_3 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h6 && sla_flip_flop == 1'b0)  sla_current_address_3 <= { sla_current_address_3[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h6 && sla_flip_flop == 1'b1)  sla_current_address_3 <= { io_writedata, sla_current_address_3[7:0] };
end

reg [15:0] sla_base_counter_1;
reg [15:0] sla_base_counter_2;

always @(posedge clk) begin
    if(rst_n == 1'b0) sla_base_counter_1 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h3 && sla_flip_flop == 1'b0)  sla_base_counter_1 <= { sla_base_counter_1[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h3 && sla_flip_flop == 1'b1)  sla_base_counter_1 <= { io_writedata, sla_base_counter_1[7:0] };
end
always @(posedge clk) begin
    if(rst_n == 1'b0) sla_base_counter_2 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h5 && sla_flip_flop == 1'b0)  sla_base_counter_2 <= { sla_base_counter_2[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h5 && sla_flip_flop == 1'b1)  sla_base_counter_2 <= { io_writedata, sla_base_counter_2[7:0] };
end

reg [15:0] sla_current_counter_0;
reg [15:0] sla_current_counter_1;
reg [15:0] sla_current_counter_2;
reg [15:0] sla_current_counter_3;

always @(posedge clk) begin
    if(rst_n == 1'b0) sla_current_counter_0 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h1 && sla_flip_flop == 1'b0)  sla_current_counter_0 <= { sla_current_counter_0[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h1 && sla_flip_flop == 1'b1)  sla_current_counter_0 <= { io_writedata, sla_current_counter_0[7:0] };
end
always @(posedge clk) begin
    if(rst_n == 1'b0) sla_current_counter_1 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h3 && sla_flip_flop == 1'b0)  sla_current_counter_1 <= { sla_current_counter_1[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h3 && sla_flip_flop == 1'b1)  sla_current_counter_1 <= { io_writedata, sla_current_counter_1[7:0] };
     
    else if(dma_1_tc && sla_auto_1)                                           sla_current_counter_1 <= sla_base_counter_1;
    else if(dma_1_update)                                                     sla_current_counter_1 <= sla_current_counter_1 - 16'd1;    
end
always @(posedge clk) begin
    if(rst_n == 1'b0) sla_current_counter_2 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h5 && sla_flip_flop == 1'b0)  sla_current_counter_2 <= { sla_current_counter_2[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h5 && sla_flip_flop == 1'b1)  sla_current_counter_2 <= { io_writedata, sla_current_counter_2[7:0] };
    
    else if(dma_2_tc && sla_auto_2)                                           sla_current_counter_2 <= sla_base_counter_2;
    else if(dma_2_update)                                                     sla_current_counter_2 <= sla_current_counter_2 - 16'd1;
end
always @(posedge clk) begin
    if(rst_n == 1'b0)   sla_current_counter_3 <= 16'd0;
    else if(slave_write && io_address[3:0] == 4'h7 && sla_flip_flop == 1'b0)  sla_current_counter_3 <= { sla_current_counter_3[15:8], io_writedata };
    else if(slave_write && io_address[3:0] == 4'h7 && sla_flip_flop == 1'b1)  sla_current_counter_3 <= { io_writedata, sla_current_counter_3[7:0] };
end

reg sla_disabled;
always @(posedge clk) begin
    if(rst_n == 1'b0)   sla_disabled <= 1'b0;
    else if(sla_reset)  sla_disabled <= 1'b0;
    else if(slave_write && io_address[3:0] == 4'h8) sla_disabled <= io_writedata[2];
end

wire [3:0] sla_writedata_bits = (4'b0001 << io_writedata[1:0]);

wire [3:0] sla_pending_next = { 1'b0, dma_2_req, dma_1_req, 1'b0 };

reg [3:0] sla_pending;
always @(posedge clk) begin
    if(rst_n == 1'b0)   sla_pending <= 4'd0;
    else if(sla_reset)  sla_pending <= 4'd0;
    else if(slave_write && io_address[3:0] == 4'h9 && io_writedata[2])     sla_pending <= sla_pending | sla_writedata_bits;
    else if(slave_write && io_address[3:0] == 4'h9 && ~io_writedata[2])    sla_pending <= sla_pending & ~(sla_writedata_bits);
    else                                                                   sla_pending <= sla_pending_next;
end

reg [3:0] sla_mask;
always @(posedge clk) begin
    if(rst_n == 1'b0)   sla_mask <= 4'hF;
    else if(sla_reset)  sla_mask <= 4'hF;
    else if(slave_write && io_address[3:0] == 4'hE)                        sla_mask <= 4'h0;
    else if(slave_write && io_address[3:0] == 4'hF)                        sla_mask <= io_writedata[3:0];
    else if(slave_write && io_address[3:0] == 4'hA && io_writedata[2])     sla_mask <= sla_mask | sla_writedata_bits;
    else if(slave_write && io_address[3:0] == 4'hA && ~io_writedata[2])    sla_mask <= sla_mask & ~(sla_writedata_bits);
    
    else if(dma_1_tc && ~sla_auto_1)                                       sla_mask <= sla_mask | 4'b0010;
    else if(dma_2_tc && ~sla_auto_2)                                       sla_mask <= sla_mask | 4'b0100;
end

reg sla_decrement_1;
reg sla_decrement_2;

always @(posedge clk) begin if(rst_n == 1'b0) sla_decrement_1 <= 1'd0; else if(slave_write && io_address[3:0] == 4'hB && io_writedata[1:0] == 2'd1) sla_decrement_1 <= io_writedata[5]; end
always @(posedge clk) begin if(rst_n == 1'b0) sla_decrement_2 <= 1'd0; else if(slave_write && io_address[3:0] == 4'hB && io_writedata[1:0] == 2'd2) sla_decrement_2 <= io_writedata[5]; end

reg sla_auto_1;
reg sla_auto_2;

always @(posedge clk) begin if(rst_n == 1'b0) sla_auto_1 <= 1'd0; else if(slave_write && io_address[3:0] == 4'hB && io_writedata[1:0] == 2'd1) sla_auto_1 <= io_writedata[4]; end
always @(posedge clk) begin if(rst_n == 1'b0) sla_auto_2 <= 1'd0; else if(slave_write && io_address[3:0] == 4'hB && io_writedata[1:0] == 2'd2) sla_auto_2 <= io_writedata[4]; end

reg [1:0] sla_transfer_1;
reg [1:0] sla_transfer_2;

always @(posedge clk) begin if(rst_n == 1'b0) sla_transfer_1 <= 2'd0; else if(slave_write && io_address[3:0] == 4'hB && io_writedata[1:0] == 2'd1) sla_transfer_1 <= io_writedata[3:2]; end
always @(posedge clk) begin if(rst_n == 1'b0) sla_transfer_2 <= 2'd0; else if(slave_write && io_address[3:0] == 4'hB && io_writedata[1:0] == 2'd2) sla_transfer_2 <= io_writedata[3:2]; end

reg [3:0] sla_terminated;
always @(posedge clk) begin
    if(rst_n == 1'b0)                                    sla_terminated <= 4'h0;
    else if(sla_reset)                                   sla_terminated <= 4'h0;
    else if(slave_read_valid && io_address[3:0] == 4'h8) sla_terminated <= 4'd0;
    else if(dma_1_tc)                                    sla_terminated <= sla_terminated | 4'b0010;
    else if(dma_2_tc)                                    sla_terminated <= sla_terminated | 4'b0100;
end

//0: idle
//1: prepare read avm (goto 2) or write avm (goto 6)

//2: read avm until ~(waitrequest); goto 3
//3: read avm until readdatavalid; goto 4

//4: ack; update address; update counter (1 cycle); if tc goto 0
//5: wait for dma_req; goto 1

//6: write avm unit ~(waitrequest); goto 4

//7: verify or illegal transfer type

wire dma_2_update = dma_2_state == 3'd4;
wire dma_2_tc     = dma_2_update && sla_current_counter_2 == 16'h0000;

wire dma_1_update = dma_1_state == 3'd4;
wire dma_1_tc     = dma_1_update && sla_current_counter_1 == 16'h0000;

always @(posedge clk) begin
    if(rst_n == 1'b0)                         dma_2_terminal <= 1'b0;
    else if(dma_2_state == 3'd4 && dma_2_tc)  dma_2_terminal <= 1'b1;
    else                                      dma_2_terminal <= 1'b0;
end
always @(posedge clk) begin
    if(rst_n == 1'b0)                         dma_1_terminal <= 1'b0;
    else if(dma_1_state == 3'd4 && dma_1_tc)  dma_1_terminal <= 1'b1;
    else                                      dma_1_terminal <= 1'b0;
end

wire [3:0] sla_idle = ~sla_pending | sla_mask;
wire       sla_not_ready = sla_disabled | mas_not_ready | mas_mask[0];

reg  [2:0] dma_2_state;
always @(posedge clk) begin
    if(rst_n == 1'b0)                                       dma_2_state <= 3'd0;
    else if(sla_reset)                                      dma_2_state <= 3'd0;

    else if(dma_2_state == 3'd0 && ch_req == 2)             dma_2_state <= 3'd1;

    else if(dma_2_state == 3'd1 && sla_transfer_2 == 2'd2)  dma_2_state <= 3'd2; //read avm
    else if(dma_2_state == 3'd2 && avm_waitrequest == 1'b0) dma_2_state <= 3'd3;
    else if(dma_2_state == 3'd3 && avm_readdatavalid)       dma_2_state <= 3'd4;

    else if(dma_2_state == 3'd4)                            dma_2_state <= 3'd5;
    else if(dma_2_state == 3'd5)                            dma_2_state <= 3'd0;
    
    else if(dma_2_state == 3'd1 && sla_transfer_2 == 2'd1)  dma_2_state <= 3'd6; //write avm
    else if(dma_2_state == 3'd6 && avm_waitrequest == 1'b0) dma_2_state <= 3'd4;
     
    else if(dma_2_state == 3'd1)                            dma_2_state <= 3'd7; //verify or illegal transfer type
    else if(dma_2_state == 3'd7)                            dma_2_state <= 3'd4;
end

reg [2:0] dma_1_state;
always @(posedge clk) begin
    if(rst_n == 1'b0)                                       dma_1_state <= 3'd0;
    else if(sla_reset)                                      dma_1_state <= 3'd0;

    else if(dma_1_state == 3'd0 && ch_req == 1)             dma_1_state <= 3'd1;

    else if(dma_1_state == 3'd1 && sla_transfer_1 == 2'd2)  dma_1_state <= 3'd2; //read avm
    else if(dma_1_state == 3'd2 && avm_waitrequest == 1'b0) dma_1_state <= 3'd3;
    else if(dma_1_state == 3'd3 && avm_readdatavalid)       dma_1_state <= 3'd4;

    else if(dma_1_state == 3'd4)                            dma_1_state <= 3'd5;
    else if(dma_1_state == 3'd5)                            dma_1_state <= 3'd0;

    else if(dma_1_state == 3'd1 && sla_transfer_1 == 2'd1)  dma_1_state <= 3'd6; //write avm
    else if(dma_1_state == 3'd6 && avm_waitrequest == 1'b0) dma_1_state <= 3'd4;

    else if(dma_1_state == 3'd1)                            dma_1_state <= 3'd7; //verify or illegal transfer type
    else if(dma_1_state == 3'd7)                            dma_1_state <= 3'd4;
end

always @(posedge clk) begin
    if(rst_n == 1'b0)                                      dma_2_ack <= 1'd0;
     else if(dma_2_state == 3'd3 && avm_readdatavalid)     dma_2_ack <= 1'b1;
     else if(dma_2_state == 3'd6 && ~(avm_waitrequest))    dma_2_ack <= 1'b1;
     else if(dma_2_state == 3'd7)                          dma_2_ack <= 1'b1;
     else                                                  dma_2_ack <= 1'b0;
end

always @(posedge clk) begin
    if(rst_n == 1'b0)                                    dma_1_ack <= 1'd0;
    else if(dma_1_state == 3'd3 && avm_readdatavalid)    dma_1_ack <= 1'b1;
    else if(dma_1_state == 3'd6 && ~(avm_waitrequest))   dma_1_ack <= 1'b1;
    else if(dma_1_state == 3'd7)                         dma_1_ack <= 1'b1;
    else                                                 dma_1_ack <= 1'b0;
end

always @(posedge clk) begin if(rst_n == 1'b0) dma_2_readdata <= 8'd0; else if(avm_readdatavalid) dma_2_readdata <= avm_readdata[7:0]; end
always @(posedge clk) begin if(rst_n == 1'b0) dma_1_readdata <= 8'd0; else if(avm_readdatavalid) dma_1_readdata <= avm_readdata[7:0]; end

//------------------------------------------------------------------------------

always @(posedge clk) begin
    if(rst_n == 1'b0)            avm_address <= 24'd0;
    else if(dma_1_state == 3'd1) avm_address <= { sla_page_1,      sla_current_address_1 };
    else if(dma_5_state == 3'd1) avm_address <= { mas_page_1[7:1], mas_current_address_1, 1'b0 };
    else if(dma_2_state == 3'd1) avm_address <= { sla_page_2,      sla_current_address_2 };
end

always @(posedge clk) begin
    if(rst_n == 1'b0)            avm_16bit <= 1'd0;
    else if(dma_1_state == 3'd1) avm_16bit <= 1'b0;
    else if(dma_5_state == 3'd1) avm_16bit <= 1'b1;
    else if(dma_2_state == 3'd1) avm_16bit <= 1'b0;
end

always @(posedge clk) begin
    if(rst_n == 1'b0)   avm_read <= 1'd0;
    
    else if(dma_1_state == 3'd1 && sla_transfer_1 == 2'd2)  avm_read <= 1'b1;
    else if(dma_1_state == 3'd2 && avm_waitrequest == 1'b0) avm_read <= 1'b0;
    
    else if(dma_5_state == 3'd1 && mas_transfer_1 == 2'd2)  avm_read <= 1'b1;
    else if(dma_5_state == 3'd2 && avm_waitrequest == 1'b0) avm_read <= 1'b0;

    else if(dma_2_state == 3'd1 && sla_transfer_2 == 2'd2)  avm_read <= 1'b1;
    else if(dma_2_state == 3'd2 && avm_waitrequest == 1'b0) avm_read <= 1'b0;
end

always @(posedge clk) begin
    if(rst_n == 1'b0)   avm_write <= 1'd0;
    
    else if(dma_1_state == 3'd1 && sla_transfer_1 == 2'd1)  avm_write <= 1'b1;
    else if(dma_1_state == 3'd6 && avm_waitrequest == 1'b0) avm_write <= 1'b0;
    
    else if(dma_5_state == 3'd1 && mas_transfer_1 == 2'd1)  avm_write <= 1'b1;
    else if(dma_5_state == 3'd6 && avm_waitrequest == 1'b0) avm_write <= 1'b0;

    else if(dma_2_state == 3'd1 && sla_transfer_2 == 2'd1)  avm_write <= 1'b1;
    else if(dma_2_state == 3'd6 && avm_waitrequest == 1'b0) avm_write <= 1'b0;
end

always @(posedge clk) begin
    if(rst_n == 1'b0)                                       avm_writedata <= 8'd0;
    else if(dma_1_state == 3'd1 && sla_transfer_1 == 2'd1)  avm_writedata <= dma_1_writedata;
    else if(dma_5_state == 3'd1 && mas_transfer_1 == 2'd1)  avm_writedata <= dma_5_writedata;
    else if(dma_2_state == 3'd1 && sla_transfer_2 == 2'd1)  avm_writedata <= dma_2_writedata;
end

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

wire [7:0] mas_readdata_prepared =
    (io_address == 5'h00 && mas_flip_flop == 1'b0) ? mas_current_address_0[7:0] :
    (io_address == 5'h00 && mas_flip_flop == 1'b1) ? mas_current_address_0[15:8] :
    (io_address == 5'h04 && mas_flip_flop == 1'b0) ? mas_current_address_1[7:0] :
    (io_address == 5'h04 && mas_flip_flop == 1'b1) ? mas_current_address_1[15:8] :
    (io_address == 5'h08 && mas_flip_flop == 1'b0) ? mas_current_address_2[7:0] :
    (io_address == 5'h08 && mas_flip_flop == 1'b1) ? mas_current_address_2[15:8] :
    (io_address == 5'h0C && mas_flip_flop == 1'b0) ? mas_current_address_3[7:0] :
    (io_address == 5'h0C && mas_flip_flop == 1'b1) ? mas_current_address_3[15:8] :
    
    (io_address == 5'h02 && mas_flip_flop == 1'b0) ? mas_current_counter_0[7:0] :
    (io_address == 5'h02 && mas_flip_flop == 1'b1) ? mas_current_counter_0[15:8] :
    (io_address == 5'h06 && mas_flip_flop == 1'b0) ? mas_current_counter_1[7:0] :
    (io_address == 5'h06 && mas_flip_flop == 1'b1) ? mas_current_counter_1[15:8] :
    (io_address == 5'h0A && mas_flip_flop == 1'b0) ? mas_current_counter_2[7:0] :
    (io_address == 5'h0A && mas_flip_flop == 1'b1) ? mas_current_counter_2[15:8] :
    (io_address == 5'h0E && mas_flip_flop == 1'b0) ? mas_current_counter_3[7:0] :
    (io_address == 5'h0E && mas_flip_flop == 1'b1) ? mas_current_counter_3[15:8] :

    (io_address == 5'h10)?                         { mas_pending, 4'd0 } :

    (io_address == 5'h1E)?                         { 4'hF, mas_mask } :
                                                     8'd0; //temp reg
    

wire mas_reset = master_write && io_address == 5'h1A;

wire mas_flop_flop_flip = (master_read_valid || master_write) && io_address[0] == 1'b0 && (io_address <= 5'h0E);

reg mas_flip_flop;
always @(posedge clk) begin
    if(rst_n == 1'b0)                               mas_flip_flop <= 1'b0;
    else if(mas_reset)                              mas_flip_flop <= 1'b0;
    else if(master_write && io_address == 5'h18)    mas_flip_flop <= 1'b0;
    else if(mas_flop_flop_flip)                     mas_flip_flop <= ~mas_flip_flop;
end

reg [15:0] mas_base_address_1;
always @(posedge clk) begin
    if(rst_n == 1'b0) mas_base_address_1 <= 16'd0;
    else if(master_write && io_address == 5'h04 && mas_flip_flop == 1'b0)  mas_base_address_1 <= { mas_base_address_1[15:8], io_writedata };
    else if(master_write && io_address == 5'h04 && mas_flip_flop == 1'b1)  mas_base_address_1 <= { io_writedata, mas_base_address_1[7:0] };
end

reg [15:0] mas_current_address_0;
reg [15:0] mas_current_address_1;
reg [15:0] mas_current_address_2;
reg [15:0] mas_current_address_3;

always @(posedge clk) begin
    if(rst_n == 1'b0) mas_current_address_0 <= 16'd0;
    else if(master_write && io_address == 5'h00 && mas_flip_flop == 1'b0)  mas_current_address_0 <= { mas_current_address_0[15:8], io_writedata };
    else if(master_write && io_address == 5'h00 && mas_flip_flop == 1'b1)  mas_current_address_0 <= { io_writedata, mas_current_address_0[7:0] };
end

always @(posedge clk) begin
    if(rst_n == 1'b0) mas_current_address_1 <= 16'd0;
    else if(master_write && io_address == 5'h04 && mas_flip_flop == 1'b0)  mas_current_address_1 <= { mas_current_address_1[15:8], io_writedata };
    else if(master_write && io_address == 5'h04 && mas_flip_flop == 1'b1)  mas_current_address_1 <= { io_writedata, mas_current_address_1[7:0] };

    else if(dma_5_tc && mas_auto_1)                                        mas_current_address_1 <= mas_base_address_1;     
    else if(dma_5_update && ~mas_decrement_1)                              mas_current_address_1 <= mas_current_address_1 + 16'd1;
    else if(dma_5_update &&  mas_decrement_1)                              mas_current_address_1 <= mas_current_address_1 - 16'd1;
end

always @(posedge clk) begin
    if(rst_n == 1'b0) mas_current_address_2 <= 16'd0;
    else if(master_write && io_address == 5'h08 && mas_flip_flop == 1'b0)  mas_current_address_2 <= { mas_current_address_2[15:8], io_writedata };
    else if(master_write && io_address == 5'h08 && mas_flip_flop == 1'b1)  mas_current_address_2 <= { io_writedata, mas_current_address_2[7:0] };
end
always @(posedge clk) begin
    if(rst_n == 1'b0) mas_current_address_3 <= 16'd0;
    else if(master_write && io_address == 5'h0C && mas_flip_flop == 1'b0)  mas_current_address_3 <= { mas_current_address_3[15:8], io_writedata };
    else if(master_write && io_address == 5'h0C && mas_flip_flop == 1'b1)  mas_current_address_3 <= { io_writedata, mas_current_address_3[7:0] };
end

reg [15:0] mas_base_counter_1;
always @(posedge clk) begin
    if(rst_n == 1'b0) mas_base_counter_1 <= 16'd0;
    else if(master_write && io_address == 5'h06 && mas_flip_flop == 1'b0)  mas_base_counter_1 <= { mas_base_counter_1[15:8], io_writedata };
    else if(master_write && io_address == 5'h06 && mas_flip_flop == 1'b1)  mas_base_counter_1 <= { io_writedata, mas_base_counter_1[7:0] };
end

reg [15:0] mas_current_counter_0;
reg [15:0] mas_current_counter_1;
reg [15:0] mas_current_counter_2;
reg [15:0] mas_current_counter_3;

always @(posedge clk) begin
    if(rst_n == 1'b0) mas_current_counter_0 <= 16'd0;
    else if(master_write && io_address == 5'h02 && mas_flip_flop == 1'b0)  mas_current_counter_0 <= { mas_current_counter_0[15:8], io_writedata };
    else if(master_write && io_address == 5'h02 && mas_flip_flop == 1'b1)  mas_current_counter_0 <= { io_writedata, mas_current_counter_0[7:0] };
end
always @(posedge clk) begin
    if(rst_n == 1'b0) mas_current_counter_1 <= 16'd0;
    else if(master_write && io_address == 5'h06 && mas_flip_flop == 1'b0)  mas_current_counter_1 <= { mas_current_counter_1[15:8], io_writedata };
    else if(master_write && io_address == 5'h06 && mas_flip_flop == 1'b1)  mas_current_counter_1 <= { io_writedata, mas_current_counter_1[7:0] };

    else if(dma_5_tc && mas_auto_1)                                        mas_current_counter_1 <= mas_base_counter_1;
    else if(dma_5_update)                                                  mas_current_counter_1 <= mas_current_counter_1 - 16'd1;    
end
always @(posedge clk) begin
    if(rst_n == 1'b0) mas_current_counter_2 <= 16'd0;
    else if(master_write && io_address == 5'h0A && mas_flip_flop == 1'b0)  mas_current_counter_2 <= { mas_current_counter_2[15:8], io_writedata };
    else if(master_write && io_address == 5'h0A && mas_flip_flop == 1'b1)  mas_current_counter_2 <= { io_writedata, mas_current_counter_2[7:0] };
end
always @(posedge clk) begin
    if(rst_n == 1'b0)   mas_current_counter_3 <= 16'd0;
    else if(master_write && io_address == 5'h0E && mas_flip_flop == 1'b0)  mas_current_counter_3 <= { mas_current_counter_3[15:8], io_writedata };
    else if(master_write && io_address == 5'h0E && mas_flip_flop == 1'b1)  mas_current_counter_3 <= { io_writedata, mas_current_counter_3[7:0] };
end

reg mas_disabled;
always @(posedge clk) begin
    if(rst_n == 1'b0)                               mas_disabled <= 1'b0;
    else if(mas_reset)                              mas_disabled <= 1'b0;
    else if(master_write && io_address == 5'h10)    mas_disabled <= io_writedata[2];
end

wire [3:0] mas_writedata_bits = (4'b0001 << io_writedata[1:0]);

wire [3:0] mas_pending_next = { 1'b0, 1'b0, dma_5_req, |sla_pending_next };

reg [3:0] mas_pending;
always @(posedge clk) begin
    if(rst_n == 1'b0)   mas_pending <= 4'd0;
    else if(mas_reset)  mas_pending <= 4'd0;
    else if(master_write && io_address == 5'h12 && io_writedata[2])     mas_pending <= mas_pending | mas_writedata_bits;
    else if(master_write && io_address == 5'h12 && ~io_writedata[2])    mas_pending <= mas_pending & ~(mas_writedata_bits);
    else                                                                mas_pending <= mas_pending_next;
end

reg [3:0] mas_mask;
always @(posedge clk) begin
    if(rst_n == 1'b0)   mas_mask <= 4'hF;
    else if(mas_reset)  mas_mask <= 4'hF;
    else if(master_write && io_address == 5'h1C)                        mas_mask <= 4'h0;
    else if(master_write && io_address == 5'h1E)                        mas_mask <= io_writedata[3:0];
    else if(master_write && io_address == 5'h14 && io_writedata[2])     mas_mask <= mas_mask | mas_writedata_bits;
    else if(master_write && io_address == 5'h14 && ~io_writedata[2])    mas_mask <= mas_mask & ~(mas_writedata_bits);

    else if(dma_5_tc && ~(mas_auto_1))                                  mas_mask <= mas_mask | 4'b0010;
end

reg mas_decrement_1;
always @(posedge clk) begin if(rst_n == 1'b0) mas_decrement_1 <= 1'd0; else if(master_write && io_address == 5'h16 && io_writedata[1:0] == 2'd1) mas_decrement_1 <= io_writedata[5]; end

reg mas_auto_1;
always @(posedge clk) begin if(rst_n == 1'b0) mas_auto_1 <= 1'd0; else if(master_write && io_address == 5'h16 && io_writedata[1:0] == 2'd1) mas_auto_1 <= io_writedata[4]; end

reg [1:0] mas_transfer_1;
always @(posedge clk) begin if(rst_n == 1'b0) mas_transfer_1 <= 2'd0; else if(master_write && io_address == 5'h16 && io_writedata[1:0] == 2'd1) mas_transfer_1 <= io_writedata[3:2]; end

reg [3:0] mas_terminated;
always @(posedge clk) begin
    if(rst_n == 1'b0)                                 mas_terminated <= 4'h0;
    else if(mas_reset)                                mas_terminated <= 4'h0;
    else if(master_read_valid && io_address == 5'h10) mas_terminated <= 4'd0;
    else if(dma_5_tc)                                 mas_terminated <= mas_terminated | 4'b0010;
end

wire dma_5_update = dma_5_state == 3'd4;
wire dma_5_tc     = dma_5_update && mas_current_counter_1 == 16'h0000;

always @(posedge clk) begin
    if(rst_n == 1'b0)                        dma_5_terminal <= 1'b0;
    else if(dma_5_state == 3'd4 && dma_5_tc) dma_5_terminal <= 1'b1;
    else                                     dma_5_terminal <= 1'b0;
end

wire [3:0] mas_idle = ~mas_pending | mas_mask;

reg [2:0] dma_5_state;
always @(posedge clk) begin
    if(rst_n == 1'b0)                                       dma_5_state <= 3'd0;
    else if(mas_reset)                                      dma_5_state <= 3'd0;
    
    else if(dma_5_state == 3'd0 && ch_req == 5)             dma_5_state <= 3'd1;
     
    else if(dma_5_state == 3'd1 && mas_transfer_1 == 2'd2)  dma_5_state <= 3'd2; //read avm
    else if(dma_5_state == 3'd2 && avm_waitrequest == 1'b0) dma_5_state <= 3'd3;
    else if(dma_5_state == 3'd3 && avm_readdatavalid)       dma_5_state <= 3'd4;
    
    else if(dma_5_state == 3'd4)                            dma_5_state <= 3'd5;
    else if(dma_5_state == 3'd5)                            dma_5_state <= 3'd0;
    
    else if(dma_5_state == 3'd1 && mas_transfer_1 == 2'd1)  dma_5_state <= 3'd6; //write avm
    else if(dma_5_state == 3'd6 && avm_waitrequest == 1'b0) dma_5_state <= 3'd4;
     
    else if(dma_5_state == 3'd1)                            dma_5_state <= 3'd7; //verify or illegal transfer type
    else if(dma_5_state == 3'd7)                            dma_5_state <= 3'd4;
end

always @(posedge clk) begin
    if(rst_n == 1'b0)                                  dma_5_ack <= 1'd0;
    else if(dma_5_state == 3'd3 && avm_readdatavalid)  dma_5_ack <= 1'b1;
    else if(dma_5_state == 3'd6 && ~avm_waitrequest)   dma_5_ack <= 1'b1;
    else if(dma_5_state == 3'd7)                       dma_5_ack <= 1'b1;
    else                                               dma_5_ack <= 1'b0;
end

always @(posedge clk) begin if(rst_n == 1'b0) dma_5_readdata <= 8'd0; else if(avm_readdatavalid) dma_5_readdata <= avm_readdata; end

wire mas_not_ready = mas_disabled;

//------------------------------------------------------------------------------

wire dma_busy = (dma_1_state != 0) || (dma_1_state != 0) || (dma_5_state != 0);

wire [2:0] ch_req = dma_busy ?                       3'd4 :
                   (~sla_idle[1] & ~sla_not_ready) ? 3'd1 :
                   (~sla_idle[2] & ~sla_not_ready) ? 3'd2 :
                   (~mas_idle[1] & ~mas_not_ready) ? 3'd5 :
						                                   3'd4;

//------------------------------------------------------------------------------

endmodule
