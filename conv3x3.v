`timescale 1ns / 1ps

module conv3x3 (
    input               clk,                // 时钟信号
    input               rst_n,              // 异步复位，低电平有效
    input               data_in_valid,      // 输入数据有效信号
    input       [7:0]   data_in_0,          // 3x3窗口输入数据 (无符号)
    input       [7:0]   data_in_1,
    input       [7:0]   data_in_2,
    input       [7:0]   data_in_3,
    input       [7:0]   data_in_4,
    input       [7:0]   data_in_5,
    input       [7:0]   data_in_6,
    input       [7:0]   data_in_7,
    input       [7:0]   data_in_8,
    input               weight_en,          // 权重使能信号
    input signed [7:0]  bias_data,          // 偏置数据，有符号，Q1.7格式
    input       [71:0]  weights_data,      // 72位权重数据，分解为9个8位权重
    
    output reg          data_out_valid,     // 输出数据有效信号
    output reg signed [17:0] data_out        // 卷积结果，18位有符号数(Q1.17格式)
);

// 权重寄存器，从72位weights_data分解而来
reg signed [7:0] weight_00, weight_01, weight_02;
reg signed [7:0] weight_10, weight_11, weight_12;
reg signed [7:0] weight_20, weight_21, weight_22;

// 输入数据流水线寄存器（无符号转有符号）
reg signed [8:0] data_in_0_signed, data_in_1_signed, data_in_2_signed;
reg signed [8:0] data_in_3_signed, data_in_4_signed, data_in_5_signed;
reg signed [8:0] data_in_6_signed, data_in_7_signed, data_in_8_signed;

// 第一级流水线：乘法结果
reg signed [16:0] prod_00, prod_01, prod_02;
reg signed [16:0] prod_10, prod_11, prod_12;
reg signed [16:0] prod_20, prod_21, prod_22;

// 第二级流水线：行求和结果
reg signed [17:0] sum_row0, sum_row1, sum_row2;

// 第三级流水线：总和计算（新增一级流水线）
reg signed [17:0] sum_total;

// 有效信号流水线（增加一级，共四级）
reg valid_d1, valid_d2, valid_d3, valid_d4;  // 添加 valid_d4


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        weight_00 <= 8'sb0; weight_01 <= 8'sb0; weight_02 <= 8'sb0;
        weight_10 <= 8'sb0; weight_11 <= 8'sb0; weight_12 <= 8'sb0;
        weight_20 <= 8'sb0; weight_21 <= 8'sb0; weight_22 <= 8'sb0;
    end else if (weight_en) begin
        // 从72位weights_data中分解9个8位权重
        weight_00 <= $signed(weights_data[7:0]);
        weight_01 <= $signed(weights_data[15:8]);
        weight_02 <= $signed(weights_data[23:16]);
        weight_10 <= $signed(weights_data[31:24]);
        weight_11 <= $signed(weights_data[39:32]);
        weight_12 <= $signed(weights_data[47:40]);
        weight_20 <= $signed(weights_data[55:48]);
        weight_21 <= $signed(weights_data[63:56]);
        weight_22 <= $signed(weights_data[71:64]);
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_in_0_signed <= 9'sb0; data_in_1_signed <= 9'sb0; data_in_2_signed <= 9'sb0;
        data_in_3_signed <= 9'sb0; data_in_4_signed <= 9'sb0; data_in_5_signed <= 9'sb0;
        data_in_6_signed <= 9'sb0; data_in_7_signed <= 9'sb0; data_in_8_signed <= 9'sb0;
        valid_d1 <= 1'b0;
    end else begin
        data_in_0_signed <= {1'b0, data_in_0};
        data_in_1_signed <= {1'b0, data_in_1};
        data_in_2_signed <= {1'b0, data_in_2};
        data_in_3_signed <= {1'b0, data_in_3};
        data_in_4_signed <= {1'b0, data_in_4};
        data_in_5_signed <= {1'b0, data_in_5};
        data_in_6_signed <= {1'b0, data_in_6};
        data_in_7_signed <= {1'b0, data_in_7};
        data_in_8_signed <= {1'b0, data_in_8};
        valid_d1 <= data_in_valid;
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        prod_00 <= 17'sb0; prod_01 <= 17'sb0; prod_02 <= 17'sb0;
        prod_10 <= 17'sb0; prod_11 <= 17'sb0; prod_12 <= 17'sb0;
        prod_20 <= 17'sb0; prod_21 <= 17'sb0; prod_22 <= 17'sb0;
        valid_d2 <= 1'b0;
    end else begin
        prod_00 <= data_in_0_signed * weight_00;
        prod_01 <= data_in_1_signed * weight_01;
        prod_02 <= data_in_2_signed * weight_02;
        prod_10 <= data_in_3_signed * weight_10;
        prod_11 <= data_in_4_signed * weight_11;
        prod_12 <= data_in_5_signed * weight_12;
        prod_20 <= data_in_6_signed * weight_20;
        prod_21 <= data_in_7_signed * weight_21;
        prod_22 <= data_in_8_signed * weight_22;
        valid_d2 <= valid_d1;
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum_row0 <= 18'sb0;
        sum_row1 <= 18'sb0;
        sum_row2 <= 18'sb0;
        valid_d3 <= 1'b0;
    end else begin
        sum_row0 <= prod_00 + prod_01 + prod_02;
        sum_row1 <= prod_10 + prod_11 + prod_12;
        sum_row2 <= prod_20 + prod_21 + prod_22;
        valid_d3 <= valid_d2;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum_total <= 18'sb0;
        valid_d4 <= 1'b0;  // 初始化新增的有效信号寄存器
    end else begin
        // 计算三行结果的总和
        sum_total <= sum_row0 + sum_row1 + sum_row2;
        // 有效信号延迟一级
        valid_d4 <= valid_d3;
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out <= 18'sb0;
        data_out_valid <= 1'b0;
    end else begin
        // 加上偏置（偏置为Q1.7格式，需要左移10位对齐）
        data_out <= sum_total + ({{10{bias_data[7]}}, bias_data, 1'b0});
        // 有效信号与数据同步输出
        data_out_valid <= valid_d4;
    end
end

endmodule