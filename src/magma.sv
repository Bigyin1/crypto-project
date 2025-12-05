// ================================================
// Шифр МаГМА (ГОСТ 28147-89) - SystemVerilog реализация
// ================================================

module magma_cipher #(
    parameter int BLOCK_SIZE = 64,  // Размер блока (бит)
    parameter int KEY_SIZE   = 256  // Размер ключа (бит)
) (
    // Тактовый сигнал и сброс
    input logic clk,
    input logic rst_n,

    // Интерфейс данных
    input logic [BLOCK_SIZE-1:0] data_in,  // Входные данные
    input logic [  KEY_SIZE-1:0] key_in,   // Ключ
    input logic                  start,    // Сигнал начала операции
    input logic                  encrypt,  // 1 - шифрование, 0 - дешифрование

    // Выходные сигналы
    output logic [BLOCK_SIZE-1:0] data_out,  // Результат
    output logic                  busy,      // Устройство занято
    output logic                  ready      // Результат готов
);

  // ================================================
  // Типы и константы
  // ================================================
  typedef logic [31:0] word_t;
  typedef logic [63:0] block_t;

  // S-блоки (рекомендованные ГОСТ Р 34.12-2015)
  localparam [3:0] SBOXES[8][16] = '{
    '{12, 4, 6, 2, 10, 5, 11, 9, 14, 8, 13, 7, 0, 3, 15, 1}, 
    '{6, 8, 2, 3, 9, 10, 5, 12, 1, 14, 4, 7, 11, 13, 0, 15},
    '{11, 3, 5, 8, 2, 15, 10, 13, 14, 1, 7, 4, 12, 9, 6, 0},
    '{12, 8, 2, 1, 13, 4, 15, 6, 7, 0, 10, 5, 3, 14, 9, 11},
    '{7, 15, 5, 10, 8, 1, 6, 13, 0, 9, 3, 14, 11, 4, 2, 12},
    '{5, 13, 15, 6, 9, 2, 12, 10, 11, 7, 8, 1, 4, 3, 14, 0},
    '{8, 14, 2, 5, 6, 9, 1, 12, 15, 4, 11, 0, 13, 10, 3, 7},
    '{1, 7, 14, 13, 0, 5, 8, 3, 4, 15, 10, 6, 9, 12, 11, 2}
};

  // ================================================
  // Внутренние сигналы
  // ================================================
  word_t [31:0] iter_keys;  // 8 подключей по 32 бита
  word_t left_reg, right_reg;  // Регистры для левой и правой частей


  logic [4:0] round_counter;  // Счетчик раундов (0-31)
  logic       processing;  // Флаг выполнения шифрования

  // ================================================
  // Генерация подключей
  // ================================================
  function automatic word_t [31:0] generate_iteration_keys(logic [KEY_SIZE-1:0] key);
    // Извлекаем 8 подключей из 256-битного ключа
    word_t [7:0]  subkeys;
    word_t [31:0] result;
  
    for (int i = 0; i < 8; i++) begin
        subkeys[i] = key[i*32 +:32];
    end
    
    // Формирование 24 ключей для раундов 0-23
    for (int i = 0; i < 24; i++) begin
        result[i] = subkeys[i % 8];
    end
    
    // Формирование ключей для раундов 24-31 (обратный порядок)
    for (int i = 0; i < 8; i++) begin
        result[24 + i] = subkeys[7 - i];
    end

    return result;
  endfunction

  
  function automatic word_t transform_t(word_t w);
    word_t result;

    for (int i=0; i<8; ++i) begin
      result[4*i +:4] = SBOXES[i][w[4*i +:4]];
    end

    return result;
  endfunction

  function automatic word_t transform_g(word_t a, word_t k);
    word_t sum;
    word_t t_trans;

    sum = a + k;
    t_trans = transform_t(sum);

    return {t_trans[20:0], t_trans[31:21]};
  endfunction


  typedef enum logic [2:0] {
    IDLE,
    INIT,
    ENCR,
    DECR,
    READY
  } magma_state_t;

  magma_state_t state;
  magma_state_t next_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT:  next_state = encrypt ? ENCR : DECR;
      ENCR: begin
        if (round_counter == 31) next_state = READY;
      end
      DECR: begin
        if (round_counter == 31) next_state = READY;
      end
      READY:
        next_state = IDLE;
    endcase
  end

  assign ready      = state == READY;
  assign data_out   = {right_reg, left_reg};


  assign busy       = state != IDLE;
  assign processing = state == ENCR || state == DECR;

  assign iter_keys    = generate_iteration_keys(key_in);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      left_reg  <= '0;
      right_reg <= '0;
    end else if (state == INIT) begin
      left_reg  <= data_in[63:32];  // Старшие 32 бита
      right_reg <= data_in[31:0];   // Младшие 32 бита
    end else if (processing) begin
      // Выполнение одного раунда

      if (round_counter < 31) begin
        left_reg  <= right_reg;
        right_reg <= left_reg ^ transform_g(iter_keys[round_counter], right_reg);
      end else begin
        left_reg  <= left_reg ^ transform_g(iter_keys[round_counter], right_reg);
      end
      end
  end


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      round_counter <= '0;
    end else if (state == INIT) begin
      round_counter <= '0;
    end else if (processing)
      round_counter <= round_counter + 1;
  end

endmodule


// ================================================
// Модуль режима простой замены (ECB)
// ================================================
module magma_ecb #(
    parameter int BLOCK_SIZE = 64,
    parameter int KEY_SIZE   = 256
) (
    input logic clk,
    input logic rst_n,

    // Интерфейс данных
    input logic [BLOCK_SIZE-1:0] plaintext,
    input logic [KEY_SIZE-1:0] key,
    input logic start,
    input logic encrypt,  // 1 - шифрование, 0 - дешифрование

    // Выходные сигналы
    output logic [BLOCK_SIZE-1:0] ciphertext,
    output logic valid,
    output logic busy
);

  magma_cipher #(
      .BLOCK_SIZE(BLOCK_SIZE),
      .KEY_SIZE  (KEY_SIZE)
  ) cipher_inst (
      .clk(clk),
      .rst_n(rst_n),
      .data_in(plaintext),
      .key_in(key),
      .start(start),
      .encrypt(encrypt),
      .data_out(ciphertext),
      .busy(busy),
      .ready(valid)
  );

endmodule


// ================================================
// Модуль режима гаммирования (CTR)
// ================================================
// module magma_ctr #(
//     parameter int BLOCK_SIZE = 64,
//     parameter int KEY_SIZE   = 256
// ) (
//     input logic clk,
//     input logic rst_n,

//     // Интерфейс данных
//     input logic [BLOCK_SIZE-1:0] data_in,
//     input logic [  KEY_SIZE-1:0] key,
//     input logic [BLOCK_SIZE-1:0] iv,       // Initialization Vector
//     input logic                  start,

//     // Выходные сигналы
//     output logic [BLOCK_SIZE-1:0] data_out,
//     output logic valid,
//     output logic busy
// );

//   logic [BLOCK_SIZE-1:0] counter;
//   logic [BLOCK_SIZE-1:0] keystream;
//   logic cipher_ready;
//   logic cipher_busy;
//   logic internal_start;

//   magma_cipher #(
//       .BLOCK_SIZE(BLOCK_SIZE),
//       .KEY_SIZE  (KEY_SIZE)
//   ) cipher_inst (
//       .clk     (clk),
//       .rst_n   (rst_n),
//       .data_in (counter),
//       .key_in  (key),
//       .start   (internal_start),
//       .encrypt (1'b1),            // В CTR всегда шифрование
//       .data_out(keystream),
//       .busy    (cipher_busy),
//       .ready   (cipher_ready)
//   );

//   // Управление счетчиком
//   always_ff @(posedge clk or negedge rst_n) begin
//     if (!rst_n) begin
//       counter <= iv;
//       data_out <= '0;
//       valid <= 1'b0;
//       internal_start <= 1'b0;
//     end else begin
//       if (start && !busy) begin
//         internal_start <= 1'b1;
//         busy <= 1'b1;
//       end else if (internal_start) begin
//         internal_start <= 1'b0;
//       end

//       if (cipher_ready) begin
//         // XOR с гаммой
//         data_out <= data_in ^ keystream;
//         valid <= 1'b1;
//         busy <= 1'b0;
//         // Увеличение счетчика
//         counter <= counter + 1;
//       end else begin
//         valid <= 1'b0;
//       end
//     end
//   end

//   assign busy = cipher_busy || internal_start;

// endmodule
