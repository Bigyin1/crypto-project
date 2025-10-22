


module sha256
  import sha256_pkg::*;
(
    input logic clk_i,
    input logic rstn_i,


    input logic [511:0] message_blk_i,
    input logic         message_blk_vld_i,

    output logic [255:0] hash_o,
    output logic         hash_vld_o
);


  // Внутренние регистры состояния
  logic [31:0] a, b, c, d, e, f, g, h;
  logic [31:0] h0, h1, h2, h3, h4, h5, h6, h7;
  logic [5:0] main_cnt;

  logic [31:0] W[0:63];
  logic [5:0] W_cnt;


  state_t current_state;


  always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
      current_state <= IDLE;
    end else begin
      case (current_state)
        IDLE: begin
          if (message_blk_vld_i) begin
            current_state <= INIT;
          end
        end
        INIT: begin
          current_state <= PREP;
        end
        PREP: begin
          if (W_cnt == 63) current_state <= HASHING;
        end
        HASHING: begin
          if (main_cnt == 63) current_state <= UPD;
        end
        UPD: begin
          current_state <= DONE;
        end
        DONE: begin
          current_state <= IDLE;
        end
        default: begin
        end

      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (current_state == INIT) W_cnt <= 16;
    if (current_state == PREP) W_cnt <= W_cnt + 1;
  end

  genvar i;

  generate;
  for (i=0; i<16; ++i) begin
    always_ff @(posedge clk_i) begin
      if (current_state == INIT) begin
        W[i] <= message_blk_i[32*(i+1)-1:32*i];
      end
    end
  end
  endgenerate

  always_ff @(posedge clk_i) begin
    if (current_state == PREP) begin
      W[W_cnt] <= W[W_cnt-16] + sigma0(W[W_cnt-15]) + W[W_cnt-7] + sigma1(W[W_cnt-2]);
    end
  end



  always_ff @(posedge clk_i) begin
    if (current_state == INIT) main_cnt <= 0;
    if (current_state == HASHING) main_cnt <= main_cnt + 1;
  end


  always_ff @(posedge clk_i) begin
    if (current_state == INIT) begin
      a <= h0;
      b <= h1;
      c <= h2;
      d <= h3;
      e <= h4;
      f <= h5;
      g <= h6;
      h <= h7;
    end

    if (current_state == HASHING) begin
      h <= g;
      g <= f;
      f <= e;
      e <= d + t1(h, e, f, g, W[main_cnt], K[main_cnt]);
      d <= c;
      c <= b;
      b <= a;
      a <= t1(h, e, f, g, W[main_cnt], K[main_cnt]) + t2(a, b, c);
    end
  end


  always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
      h0 <= INIT_HASH[0];
      h1 <= INIT_HASH[1];
      h2 <= INIT_HASH[2];
      h3 <= INIT_HASH[3];
      h4 <= INIT_HASH[4];
      h5 <= INIT_HASH[5];
      h6 <= INIT_HASH[6];
      h7 <= INIT_HASH[7];
    end else if (current_state == UPD) begin
      h0 <= h0 + a;
      h1 <= h1 + b;
      h2 <= h2 + c;
      h3 <= h3 + d;
      h4 <= h4 + e;
      h5 <= h5 + f;
      h6 <= h6 + g;
      h7 <= h7 + h;
    end
  end


  // Формирование выходного хеша
  assign hash_o = {h0, h1, h2, h3, h4, h5, h6, h7};
  assign hash_vld_o = current_state == DONE;

endmodule
