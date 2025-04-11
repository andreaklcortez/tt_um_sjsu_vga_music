/*
 * "San Jose Fight Song"  
 * By: Andrea Cortez
 *
 * Copyright (c) 2024 Renaldas Zioma, Erik Hemming
 * SPDX-License-Identifier: Apache-2.0
 */ 

`default_nettype none
`include "hvsync_generator.v"

`define MUSIC_SPEED   1'b1  // for 60 FPS
// `define MUSIC_SPEED   2'd2  // for 30 FPS

`define NONE_NOTE 511  // No frequency for silence
`define C1  481 // 32.70375 Hz 
`define Cs1 454 // 34.6475 Hz 
`define D1  429 // 36.7075 Hz 
`define Ds1 405 // 38.89125 Hz 
`define E1  382 // 41.20375 Hz 
`define F1  360 // 43.65375 Hz 
`define Fs1 340 // 46.24875 Hz 
`define G1  321 // 49.0 Hz 
`define Gs1 303 // 51.9125 Hz 
`define A1  286 // 55.0 Hz 
`define As1 270 // 58.27 Hz 
`define B1  255 // 61.735 Hz 
`define C2  241 // 65.4075 Hz 
`define Cs2 227 // 69.295 Hz 
`define D2  214 // 73.415 Hz 
`define Ds2 202 // 77.7825 Hz 
`define E2  191 // 82.4075 Hz 
`define F2  180 // 87.3075 Hz 
`define Fs2 170 // 92.4975 Hz 
`define G2  161 // 98.0 Hz 
`define Gs2 152 // 103.825 Hz 
`define A2  143 // 110.0 Hz 
`define As2 135 // 116.54 Hz 
`define B2  127 // 123.47 Hz 
`define C3  120 // 130.815 Hz 
`define Cs3 114 // 138.59 Hz 
`define D3  107 // 146.83 Hz 
`define Ds3 101 // 155.565 Hz 
`define E3  95 // 164.815 Hz 
`define F3  90 // 174.615 Hz 
`define Fs3 85 // 184.995 Hz 
`define G3  80 // 196.0 Hz 
`define Gs3 76 // 207.65 Hz 
`define A3  72 // 220.0 Hz 
`define As3 68 // 233.08 Hz 
`define B3  64 // 246.94 Hz 
`define C4  60 // 261.63 Hz 
`define Cs4 57 // 277.18 Hz 
`define D4  54 // 293.66 Hz 
`define Ds4 51 // 311.13 Hz 
`define E4  48 // 329.63 Hz 
`define F4  45 // 349.23 Hz 
`define Fs4 43 // 369.99 Hz 
`define G4  40 // 392.0 Hz 
`define Gs4 38 // 415.3 Hz 
`define A4  36 // 440.0 Hz 
`define As4 34 // 466.16 Hz 
`define B4  32 // 493.88 Hz 
`define C5  30 // 523.26 Hz 
`define Cs5 28 // 554.36 Hz 
`define D5  27 // 587.32 Hz 
`define Ds5 25 // 622.26 Hz 
`define E5  24 // 659.26 Hz 
`define F5  23 // 698.46 Hz 
`define Fs5 21 // 739.98 Hz 
`define G5  20 // 784.0 Hz 
`define Gs5 19 // 830.6 Hz 
`define A5  18 // 880.0 Hz 
`define As5 17 // 932.32 Hz 
`define B5  16 // 987.76 Hz 


module tt_um_sjsu_vga_music(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

// VGA signals
wire hsync, vsync, video_active;
wire [9:0] x, y;
wire sound;
wire [1:0] R, G, B;

// Signal assignments (simplified)
assign {R,G,B} = video_active ? {6{sound}} : 6'd0;
assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
assign uio_out = {sound, 7'd0};
assign uio_oe  = 8'hff;

// Suppress unused signals warning
wire _unused_ok = &{ena, ui_in, uio_in};

// VGA sync generator instantiation
hvsync_generator hvsync_gen (
  .clk(clk),
  .reset(~rst_n),
  .hsync(hsync),
  .vsync(vsync),
  .display_on(video_active),
  .hpos(x),
  .vpos(y)
);

// Frame counter
reg [11:0] frame_counter;

always @(posedge clk) begin
  if (~rst_n)
    frame_counter <= 12'd0;
  else if (x == 0 && y == 0)
    frame_counter <= frame_counter + 12'd1; // MUSIC_SPEED = 1
end

// Noise generator (LFSR)
reg [12:0] lfsr;
wire feedback = lfsr[12] ^ lfsr[8] ^ lfsr[2] ^ lfsr[0];

always @(posedge clk) begin
  if (~rst_n)
    lfsr <= 13'h1;
  else
    lfsr <= {lfsr[11:0], feedback};
end

wire noise_src = ^lfsr;
reg noise;
reg [2:0] noise_counter;

always @(posedge clk) begin
  if (~rst_n) begin
    noise_counter <= 3'd0;
    noise <= 1'b0;
  end else if (x == 0) begin
    noise_counter <= noise_counter + 3'd1;
    if (noise_counter == 3'd2) begin
      noise_counter <= 3'd0;
      noise <= noise ^ noise_src;
    end
  end
end

// Note frequency definitions (constants)
localparam NONE_NOTE = 8'd255; // Silent note
localparam C5        = 8'd30;
localparam E5        = 8'd24;
localparam D5        = 8'd27;
localparam G4        = 8'd40;
localparam A4        = 8'd36;
localparam F5        = 8'd23;
localparam B4        = 8'd32;
localparam A1        = 9'd286;

// Lead notes lookup (ROM)
reg [7:0] note_freq;
wire [7:0] note_idx = frame_counter[11:4];

always @(*) begin
  case(note_idx)
    8'd0, 8'd6, 8'd12, 8'd32, 8'd38, 8'd44, 8'd64, 8'd112 : note_freq = C5;
    8'd2, 8'd34, 8'd72 : note_freq = E5;
    8'd8, 8'd40, 8'd76 : note_freq = D5;
    8'd16,8'd96,8'd98,8'd102 : note_freq = G4;
    8'd48,8'd86,8'd104 : note_freq = A4;
    8'd66,8'd70 : note_freq = F5;
    8'd80,8'd88,8'd108 : note_freq = B4;
    default: note_freq = NONE_NOTE;
  endcase
end

// Bass note frequency (constant A1)
wire [8:0] note2_freq = A1;

// Square wave generators
reg [7:0] note_counter;
reg note;

always @(posedge clk) begin
  if (~rst_n) begin
    note_counter <= 8'd0;
    note <= 1'b0;
  end else if (x == 0) begin
    if (note_counter >= note_freq) begin
      note_counter <= 8'd0;
      note <= ~note;
    end else
      note_counter <= note_counter + 8'd1;
  end
end

// Bass wave generator
reg [8:0] note2_counter;
reg note2;

always @(posedge clk) begin
  if (~rst_n) begin
    note2_counter <= 9'd0;
    note2 <= 1'b0;
  end else if (x == 0) begin
    if (note2_counter >= note2_freq) begin
      note2_counter <= 9'd0;
      note2 <= ~note2;
    end else
      note2_counter <= note2_counter + 9'd1;
  end
end

// Envelopes (simplified to synthesizable logic)
wire [4:0] envelopeA = 5'd31 - frame_counter[4:0];
wire [4:0] envelopeB = 5'd31 - (frame_counter[3:0] << 1);
wire beats_1_3       = (frame_counter[5:4] == 2'b10);

// Kick, Snare, Lead, Bass sound signals
wire kick  = (y < 262) & (x < (envelopeA << 2));
wire snare = noise & (x >= 128) & (x < (128 + (envelopeB << 2)));
wire lead  = note & (x >= 256) & (x < (256 + (envelopeB << 3)));
wire bass  = note2 & (x >= 512) & (x < (beats_1_3 ? 544 : 640));

// Final mixed sound output
assign sound = kick | (snare & beats_1_3 & frame_counter[11:9] != 3'd0) | bass | (lead & frame_counter[11:9] > 3'd2);

endmodule
