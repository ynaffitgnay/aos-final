/////////////////////////////////////////////////////////////////////
////                                                             ////
////  FPU                                                        ////
////  Floating Point Unit (Double precision)                     ////
////                                                             ////
////  Author: David Lundgren                                     ////
////          davidklun@gmail.com                                ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2009 David Lundgren                           ////
////                  davidklun@gmail.com                        ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

// Refactored April 2019 for Cascade compatibility by Tiffany Yang

module fpu_div( 
                clk, 
                rst, 
                enable, 
                opa, 
                opb, 
                sign, 
                mantissa_7,
                exponent_out
                );

  parameter WIDTH = 52;
  parameter WIDTH_LOG = 6;

  input wire clk;
  input wire rst;
  input wire enable;
  input wire [63:0] opa;
  input wire [63:0] opb;
  output wire sign;
  output wire [55:0] mantissa_7;
  output reg [11:0] exponent_out;

  parameter  preset  = 53;

  reg [53:0] dividend_reg;
  reg [53:0] divisor_reg;
  reg enable_reg;
  reg enable_reg_2;
  reg enable_reg_a;
  reg enable_reg_b;
  reg enable_reg_c;
  reg enable_reg_d;
  reg enable_reg_e;
  reg [5:0]   dividend_shift;
  reg [5:0]   dividend_shift_2;
  reg [5:0]   divisor_shift;
  reg [5:0]   divisor_shift_2;
  reg [5:0]   count_out;


  
  reg [51:0] mantissa_a;
  reg [51:0] mantissa_b;
  wire [10:0] expon_a = opa[62:52];
  wire [10:0] expon_b = opb[62:52];
  wire  a_is_norm = |expon_a;
  wire  b_is_norm = |expon_b;
  wire  a_is_zero = !(|opa[62:0]); 
  wire [11:0] exponent_a = { 1'b0, expon_a};
  wire [11:0] exponent_b = { 1'b0, expon_b};
  reg [51:0] dividend_a;
  reg [51:0] dividend_a_shifted;
  wire [52:0] dividend_denorm = { dividend_a_shifted, 1'b0};
  wire [53:0]  dividend_1 = a_is_norm ? { 2'b01, dividend_a } : { 1'b0, dividend_denorm};
  reg [51:0] divisor_b;
  reg [51:0] divisor_b_shifted;
  wire [52:0] divisor_denorm = { divisor_b_shifted, 1'b0};
  wire [53:0]  divisor_1 = b_is_norm ? { 2'b01, divisor_b } : { 1'b0, divisor_denorm};
  wire [5:0] count_index = count_out;
  wire count_nonzero = !(count_index == 0);
  reg [53:0] quotient;
  reg  [53:0] quotient_out;
  reg [53:0] remainder;
  reg [53:0] remainder_out;
  reg remainder_msb;
  reg count_nonzero_reg;
  reg count_nonzero_reg_2;
  reg [11:0] expon_term;
  reg expon_uf_1;
  reg [11:0] expon_uf_term_1;
  reg [11:0] expon_final_1;
  reg [11:0] expon_final_2;
  reg [11:0] expon_shift_a;
  reg [11:0] expon_shift_b;
  reg expon_uf_2;
  reg [11:0] expon_uf_term_2;
  reg [11:0] expon_uf_term_3;
  reg expon_uf_gt_maxshift;
  reg [11:0] expon_uf_term_4;
  reg [11:0] expon_final_3;
  reg [11:0] expon_final_4;
  wire quotient_msb = quotient_out[53];
  reg expon_final_4_et0;
  reg expon_final_4_term;
  reg [11:0] expon_final_5;
  reg [51:0] mantissa_1;
  wire [51:0] mantissa_2 = quotient_out[52:1];
  wire [51:0] mantissa_3 = quotient_out[51:0];
  wire [51:0] mantissa_4 = quotient_msb ? mantissa_2 : mantissa_3;
  wire [51:0] mantissa_5 = (expon_final_4 == 1) ? mantissa_2 : mantissa_4;
  wire [51:0] mantissa_6 = expon_final_4_et0 ? mantissa_1 : mantissa_5;
  wire [107:0] remainder_a = { quotient_out[53:0] , remainder_msb, remainder_out[52:0]};
  reg [6:0] remainder_shift_term;
  reg [107:0] remainder_b;
  wire [55:0] remainder_1 = remainder_b[107:52];
  wire [55:0] remainder_2 = { quotient_out[0] , remainder_msb, remainder_out[52:0], 1'b0 };
  wire [55:0] remainder_3 = { remainder_msb , remainder_out[52:0], 2'b0 };
  wire [55:0] remainder_4 = quotient_msb ? remainder_2 : remainder_3;
  wire [55:0] remainder_5 = (expon_final_4 == 1) ? remainder_2 : remainder_4;
  wire [55:0] remainder_6 = expon_final_4_et0 ? remainder_1 : remainder_5;
  wire  m_norm = |expon_final_5;
  wire  rem_lsb = |remainder_6[54:0];  

  wire [WIDTH_LOG - 1:0] msb_A;
  wire [WIDTH_LOG - 1:0] msb_B;

  assign sign = opa[63] ^ opb[63];
  assign mantissa_7 = { 1'b0, m_norm, mantissa_6, remainder_6[55], rem_lsb };

  always @ (posedge clk)
  begin
    if (rst)
      exponent_out <= 0;
    else 
      exponent_out <= a_is_zero ? 12'b0 : expon_final_5; 
  end

  always @ (posedge clk)
  begin
    if (rst)
      count_out <= 0;
    else if (enable_reg) 
      count_out <= preset;
         else if (count_nonzero)
           count_out <= count_out - 1; 
  end

  always @ (posedge clk)
  begin
    if (rst) begin
      quotient_out <= 0;
      remainder_out <= 0;
    end
    else begin
      quotient_out <= quotient;
      remainder_out <= remainder;
    end
  end


  always @ (posedge clk)
  begin
    if (rst) 
      quotient <= 0;
    else if (count_nonzero_reg)
      quotient[count_index] <= !(divisor_reg > dividend_reg);  
  end

  always @ (posedge clk)
  begin
    if (rst) begin
      remainder <= 0;
      remainder_msb <= 0;
    end  
    else if (!count_nonzero_reg & count_nonzero_reg_2) begin    
      remainder <= dividend_reg;
      remainder_msb <= (divisor_reg > dividend_reg) ? 0 : 1;
    end
  end

  always @ (posedge clk)
  begin
    if (rst) begin
      dividend_reg <= 0;
      divisor_reg <= 0;
    end
    else if (enable_reg_e) begin
      dividend_reg <= dividend_1;
      divisor_reg <= divisor_1;
    end
         else if (count_nonzero_reg)
           dividend_reg <= (divisor_reg > dividend_reg) ? dividend_reg << 1 : 
                           (dividend_reg - divisor_reg) << 1; 
    // divisor doesn't change for the divide
  end

  always @ (posedge clk)
  begin
    if (rst) begin
      expon_term  <= 0;
      expon_uf_1 <= 0;
      expon_uf_term_1 <= 0;
      expon_final_1 <= 0;
      expon_final_2 <= 0;
      expon_shift_a <= 0;
      expon_shift_b <= 0;
      expon_uf_2 <= 0;
      expon_uf_term_2 <= 0;
      expon_uf_term_3 <= 0;
      expon_uf_gt_maxshift <= 0;
      expon_uf_term_4 <= 0;
      expon_final_3 <= 0;
      expon_final_4 <= 0;
      expon_final_4_et0 <= 0;
      expon_final_4_term <= 0;
      expon_final_5 <= 0;
      mantissa_a <= 0;
      mantissa_b <= 0;
      dividend_a <= 0;
      divisor_b <= 0;
      dividend_shift_2 <= 0;
      divisor_shift_2 <= 0;
      remainder_shift_term <= 0;
      remainder_b <= 0;
      dividend_a_shifted <= 0;
      divisor_b_shifted <=  0;
      mantissa_1 <= 0;
    end
    else if (enable_reg_2) begin
      expon_term  <= exponent_a + 1023;
      expon_uf_1 <= exponent_b > expon_term;
      expon_uf_term_1 <= expon_uf_1 ? (exponent_b - expon_term) : 0;
      expon_final_1 <= expon_term - exponent_b;
      expon_final_2 <= expon_uf_1 ? 0 : expon_final_1;
      expon_shift_a <= a_is_norm ? 0 : dividend_shift_2;
      expon_shift_b <= b_is_norm ? 0 : divisor_shift_2;
      expon_uf_2 <= expon_shift_a > expon_final_2;
      expon_uf_term_2 <= expon_uf_2 ? (expon_shift_a - expon_final_2) : 0;
      expon_uf_term_3 <= expon_uf_term_2 + expon_uf_term_1;
      expon_uf_gt_maxshift <= (expon_uf_term_3 > 51);
      expon_uf_term_4 <= expon_uf_gt_maxshift ? 52 : expon_uf_term_3;
      expon_final_3 <= expon_uf_2 ? 0 : (expon_final_2 - expon_shift_a);
      expon_final_4 <= expon_final_3 + expon_shift_b;
      expon_final_4_et0 <= (expon_final_4 == 0);
      expon_final_4_term <= expon_final_4_et0 ? 0 : 1;
      expon_final_5 <= quotient_msb ? expon_final_4 : expon_final_4 - expon_final_4_term;
      mantissa_a <= opa[51:0];
      mantissa_b <= opb[51:0];
      dividend_a <= mantissa_a;
      divisor_b <= mantissa_b;
      dividend_shift_2 <= dividend_shift;
      divisor_shift_2 <= divisor_shift;
      remainder_shift_term <= 52 - expon_uf_term_4;
      remainder_b <= remainder_a << remainder_shift_term;
      dividend_a_shifted <= dividend_a << dividend_shift_2;
      divisor_b_shifted <= divisor_b << divisor_shift_2;
      mantissa_1 <= quotient_out[53:2] >> expon_uf_term_4;
    end
  end

  always @ (posedge clk)
  begin
    if (rst) begin
      count_nonzero_reg <= 0;  
      count_nonzero_reg_2 <= 0;
      enable_reg <= 0;
      enable_reg_a <= 0;
      enable_reg_b <= 0;
      enable_reg_c <= 0;
      enable_reg_d <= 0;
      enable_reg_e <= 0;
    end
    else begin
      count_nonzero_reg <= count_nonzero;   
      count_nonzero_reg_2 <= count_nonzero_reg;
      enable_reg <= enable_reg_e;
      enable_reg_a <= enable;
      enable_reg_b <= enable_reg_a;
      enable_reg_c <= enable_reg_b;
      enable_reg_d <= enable_reg_c;
      enable_reg_e <= enable_reg_d;
    end
  end

  always @ (posedge clk)
  begin
    if (rst) 
      enable_reg_2 <= 0;
    else if (enable)
      enable_reg_2 <= 1;
  end

  always @(*) dividend_shift <= msb_A ? (51 - msb_A) : (dividend_a ? 51 : 52);
  always @(*) divisor_shift <= msb_B ? (51 - msb_B) : (divisor_b ? 51 : 52);

  fpu_pri_encoder#(.WIDTH( WIDTH ), .WIDTH_LOG( WIDTH_LOG )) fe_A( dividend_a, msb_A );
  fpu_pri_encoder#(.WIDTH( WIDTH ), .WIDTH_LOG( WIDTH_LOG )) fe_B( divisor_b, msb_B );
  
endmodule
