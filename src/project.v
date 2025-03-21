/*
 * "San Jose Fight Song"  
 * By: Andrea Cortez
 *
 * Copyright (c) 2024 Renaldas Zioma, Erik Hemming
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`define MUSIC_SPEED   1'b1;  // for 60 FPS
// `define MUSIC_SPEED   2'd2;  // for 30 FPS

`define NONE_NOTE 511;  // No frequency for silence
`define C1  481; // 32.70375 Hz 
`define Cs1 454; // 34.6475 Hz 
`define D1  429; // 36.7075 Hz 
`define Ds1 405; // 38.89125 Hz 
`define E1  382; // 41.20375 Hz 
`define F1  360; // 43.65375 Hz 
`define Fs1 340; // 46.24875 Hz 
`define G1  321; // 49.0 Hz 
`define Gs1 303; // 51.9125 Hz 
`define A1  286; // 55.0 Hz 
`define As1 270; // 58.27 Hz 
`define B1  255; // 61.735 Hz 
`define C2  241; // 65.4075 Hz 
`define Cs2 227; // 69.295 Hz 
`define D2  214; // 73.415 Hz 
`define Ds2 202; // 77.7825 Hz 
`define E2  191; // 82.4075 Hz 
`define F2  180; // 87.3075 Hz 
`define Fs2 170; // 92.4975 Hz 
`define G2  161; // 98.0 Hz 
`define Gs2 152; // 103.825 Hz 
`define A2  143; // 110.0 Hz 
`define As2 135; // 116.54 Hz 
`define B2  127; // 123.47 Hz 
`define C3  120; // 130.815 Hz 
`define Cs3 114; // 138.59 Hz 
`define D3  107; // 146.83 Hz 
`define Ds3 101; // 155.565 Hz 
`define E3  95; // 164.815 Hz 
`define F3  90; // 174.615 Hz 
`define Fs3 85; // 184.995 Hz 
`define G3  80; // 196.0 Hz 
`define Gs3 76; // 207.65 Hz 
`define A3  72; // 220.0 Hz 
`define As3 68; // 233.08 Hz 
`define B3  64; // 246.94 Hz 
`define C4  60; // 261.63 Hz 
`define Cs4 57; // 277.18 Hz 
`define D4  54; // 293.66 Hz 
`define Ds4 51; // 311.13 Hz 
`define E4  48; // 329.63 Hz 
`define F4  45; // 349.23 Hz 
`define Fs4 43; // 369.99 Hz 
`define G4  40; // 392.0 Hz 
`define Gs4 38; // 415.3 Hz 
`define A4  36; // 440.0 Hz 
`define As4 34; // 466.16 Hz 
`define B4  32; // 493.88 Hz 
`define C5  30; // 523.26 Hz 
`define Cs5 28; // 554.36 Hz 
`define D5  27; // 587.32 Hz 
`define Ds5 25; // 622.26 Hz 
`define E5  24; // 659.26 Hz 
`define F5  23; // 698.46 Hz 
`define Fs5 21; // 739.98 Hz 
`define G5  20; // 784.0 Hz 
`define Gs5 19; // 830.6 Hz 
`define A5  18; // 880.0 Hz 
`define As5 17; // 932.32 Hz 
`define B5  16; // 987.76 Hz 

module tt_um_vga_example(
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
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [7:0] B;
  wire video_active;
  wire [9:0] x;
  wire [9:0] y;
  wire sound;

  // TinyVGA PMOD
  assign {R,G,B} = {6{video_active * sound}};
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = {sound, 7'b0};

  // Unused outputs assigned to 0.
  assign uio_oe  = 8'hff;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(x),
    .vpos(y)
  );

  wire [2:0] part = frame_counter[10-:3];
  wire [12:0] timer = frame_counter;
  reg noise, noise_src = ^lfsr;
  reg [2:0] noise_counter;

  // envelopes
  wire [4:0] envelopeA = 5'd31 - timer[4:0];  // exp(t*-10) decays to 0 approximately in 32 frames  [255 215 181 153 129 109  92  77  65  55  46  39  33  28  23  20  16  14 12  10   8   7   6   5   4   3   3   2   2]
  wire [4:0] envelopeB = 5'd31 - timer[3:0]*2;// exp(t*-20) decays to 0 approximately in 16 frames  [255 181 129  92  65  46  33  23  16  12   8   6   4   3]
  wire beats_1_3 = timer[5:4] == 2'b10;

  // kick wave
  wire square60hz =  y < 262;                 // standing 60Hz square wave

  // snare noise    
  reg [12:0] lfsr;
  wire feedback = lfsr[12] ^ lfsr[8] ^ lfsr[2] ^ lfsr[0] + 1;
  always @(posedge clk) begin
    lfsr <= {lfsr[11:0], feedback};
  end

  // lead wave counter
  reg [7:0] note_freq;
  reg [7:0] note_counter;
  reg       note;

  // bass wave counter
  reg [8:0] note2_freq;
  reg [8:0] note2_counter;
  reg       note2;

  // lead notes
  wire [7:0] note_in = timer[9-:8];           // 16 notes, 16 frames per note each. 256 frames total, ~4 seconds
  always @(note_in)
  case(note_in)
      8'd0 : note_freq = `C5
      8'd1 : note_freq = `NONE_NOTE
      8'd2 : note_freq = `E5
      8'd3 : note_freq = `NONE_NOTE
      8'd4 : note_freq = `NONE_NOTE
      8'd5 : note_freq = `NONE_NOTE
      8'd6 : note_freq = `C5
      8'd7 : note_freq = `NONE_NOTE
      8'd8 : note_freq = `D5
      8'd9 : note_freq = `NONE_NOTE
      8'd10: note_freq = `NONE_NOTE
      8'd11: note_freq = `NONE_NOTE
      8'd12: note_freq = `C5
      8'd13: note_freq = `NONE_NOTE
      8'd14: note_freq = `NONE_NOTE
      8'd15: note_freq = `NONE_NOTE

      8'd16: note_freq = `G4
      8'd17: note_freq = `NONE_NOTE
      8'd18: note_freq = `NONE_NOTE
      8'd19: note_freq = `NONE_NOTE
      8'd20: note_freq = `NONE_NOTE
      8'd21: note_freq = `NONE_NOTE
      8'd22: note_freq = `NONE_NOTE
      8'd23: note_freq = `NONE_NOTE
      8'd24: note_freq = `NONE_NOTE
      8'd25: note_freq = `NONE_NOTE
      8'd26: note_freq = `NONE_NOTE
      8'd27: note_freq = `NONE_NOTE
      8'd28: note_freq = `NONE_NOTE
      8'd29: note_freq = `NONE_NOTE
      8'd30: note_freq = `NONE_NOTE
      8'd31: note_freq = `NONE_NOTE

      8'd32 : note_freq = `C5
      8'd33 : note_freq = `NONE_NOTE
      8'd34 : note_freq = `E5
      8'd35 : note_freq = `NONE_NOTE
      8'd36 : note_freq = `NONE_NOTE
      8'd37 : note_freq = `NONE_NOTE
      8'd38 : note_freq = `C5
      8'd39 : note_freq = `NONE_NOTE
      8'd40 : note_freq = `D5
      8'd41 : note_freq = `NONE_NOTE
      8'd42: note_freq = `NONE_NOTE
      8'd43: note_freq = `NONE_NOTE
      8'd44: note_freq = `C5
      8'd45: note_freq = `NONE_NOTE
      8'd46: note_freq = `NONE_NOTE
      8'd47: note_freq = `NONE_NOTE

      8'd48: note_freq = `A4
      8'd49: note_freq = `NONE_NOTE
      8'd50: note_freq = `NONE_NOTE
      8'd51: note_freq = `NONE_NOTE
      8'd52: note_freq = `NONE_NOTE
      8'd53: note_freq = `NONE_NOTE
      8'd54: note_freq = `NONE_NOTE
      8'd55: note_freq = `NONE_NOTE
      8'd56: note_freq = `NONE_NOTE
      8'd57: note_freq = `NONE_NOTE
      8'd58: note_freq = `NONE_NOTE
      8'd59: note_freq = `NONE_NOTE
      8'd60: note_freq = `NONE_NOTE
      8'd61: note_freq = `NONE_NOTE
      8'd62: note_freq = `NONE_NOTE
      8'd63: note_freq = `NONE_NOTE

      8'd64 : note_freq = `C5
      8'd65 : note_freq = `NONE_NOTE
      8'd66 : note_freq = `F5
      8'd67 : note_freq = `NONE_NOTE
      8'd68 : note_freq = `NONE_NOTE
      8'd69 : note_freq = `NONE_NOTE
      8'd70 : note_freq = `F5
      8'd71 : note_freq = `NONE_NOTE
      8'd72 : note_freq = `E5
      8'd73 : note_freq = `NONE_NOTE
      8'd74: note_freq = `NONE_NOTE
      8'd75: note_freq = `NONE_NOTE
      8'd76: note_freq = `D5
      8'd77: note_freq = `NONE_NOTE
      8'd78: note_freq = `NONE_NOTE
      8'd79: note_freq = `NONE_NOTE

      8'd80 : note_freq = `B4
      8'd81 : note_freq = `NONE_NOTE
      8'd82 : note_freq = `NONE_NOTE
      8'd83 : note_freq = `NONE_NOTE
      8'd84 : note_freq = `NONE_NOTE
      8'd85 : note_freq = `NONE_NOTE
      8'd86 : note_freq = `A4
      8'd87 : note_freq = `NONE_NOTE
      8'd88 : note_freq = `B4
      8'd89 : note_freq = `NONE_NOTE
      8'd90: note_freq = `NONE_NOTE
      8'd91: note_freq = `NONE_NOTE
      8'd92: note_freq = `NONE_NOTE
      8'd93: note_freq = `NONE_NOTE
      8'd94: note_freq = `NONE_NOTE
      8'd95: note_freq = `NONE_NOTE

      8'd96 : note_freq = `G4
      8'd97 : note_freq = `NONE_NOTE
      8'd98 : note_freq = `G4
      8'd99 : note_freq = `NONE_NOTE
      8'd100 : note_freq = `NONE_NOTE
      8'd101 : note_freq = `NONE_NOTE
      8'd102 : note_freq = `G4
      8'd103 : note_freq = `NONE_NOTE
      8'd104 : note_freq = `A4
      8'd105 : note_freq = `NONE_NOTE
      8'd106 : note_freq = `NONE_NOTE
      8'd107 : note_freq = `NONE_NOTE
      8'd108 : note_freq = `B4
      8'd109 : note_freq = `NONE_NOTE
      8'd110 : note_freq = `NONE_NOTE
      8'd111 : note_freq = `NONE_NOTE
      
      8'd112 : note_freq = `C5
      8'd113 : note_freq = `NONE_NOTE
      8'd114 : note_freq = `NONE_NOTE
      8'd115 : note_freq = `NONE_NOTE
      8'd116 : note_freq = `NONE_NOTE
      8'd117 : note_freq = `NONE_NOTE
      8'd118 : note_freq = `NONE_NOTE
      8'd119 : note_freq = `NONE_NOTE
      8'd120: note_freq = `NONE_NOTE
      8'd121: note_freq = `NONE_NOTE
      8'd122: note_freq = `NONE_NOTE
      8'd123: note_freq = `NONE_NOTE
      8'd124: note_freq = `NONE_NOTE
      8'd125: note_freq = `NONE_NOTE
      8'd126: note_freq = `NONE_NOTE
      8'd127: note_freq = `NONE_NOTE

  endcase

  // bass notes
  wire [2:0] note2_in = timer[8-:3];           // 8 notes, 32 frames per note each. 256 frames total, ~4 seconds
  always @(note2_in)
  case(note2_in)
      3'd0 : note2_freq = `A1
      3'd1 : note2_freq = `A1
      3'd2 : note2_freq = `A1
      3'd3 : note2_freq = `A1
      3'd4 : note2_freq = `A1
      3'd5 : note2_freq = `A1
      3'd6 : note2_freq = `A1
      3'd7 : note2_freq = `A1
  endcase

  wire kick   = square60hz & (x < envelopeA*4);                   // 60Hz square wave with half second envelope
  wire snare  = noise      & (x >= 128 && x < 128+envelopeB*4);   // noise with half a second envelope
  wire lead   = note       & (x >= 256 && x < 256+envelopeB*8);   // ROM square wave with quarter second envelope
  wire base   = note2      & (x >= 512 && x < ((beats_1_3)?(512+8*4):(512+32*4)));  
  assign sound = { kick | (snare & beats_1_3 & part != 0) | (base) | (lead & part > 2) };

  reg [11:0] frame_counter;
  always @(posedge clk) begin
    if (~rst_n) begin
      frame_counter <= 0;
      noise_counter <= 0;
      note_counter <= 0;
      note2_counter <= 0;
      noise <= 0;
      note <= 0;
      note2 <= 0;

    end else begin

      if (x == 0 && y == 0) begin
        frame_counter <= frame_counter + `MUSIC_SPEED;
      end

      // noise
      if (x == 0) begin
        if (noise_counter > 1) begin 
          noise_counter <= 0;
          noise <= noise ^ noise_src;
        end else
          noise_counter <= noise_counter + 1'b1;
      end

      // square wave
      if (x == 0) begin
        if (note_counter > note_freq) begin
          note_counter <= 0;
          note <= ~note;
        end else begin
          note_counter <= note_counter + 1'b1;
        end

        if (note2_counter > note2_freq) begin
          note2_counter <= 0;
          note2 <= ~note2;
        end else begin
          note2_counter <= note2_counter + 1'b1;
        end
      end
    end
  end

endmodule
