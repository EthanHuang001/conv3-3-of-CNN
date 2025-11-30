`timescale 1ns/1ps
module tb_conv3x3_simple;

    // 时钟和复位
    reg clk;
    reg rst_n;
    
    // 模块输入
    reg data_in_valid;
    reg [7:0] data_in_0, data_in_1, data_in_2;
    reg [7:0] data_in_3, data_in_4, data_in_5;
    reg [7:0] data_in_6, data_in_7, data_in_8;
    reg weight_en;
    reg signed [7:0] bias_data;
    reg [71:0] weights_data;
    
    // 模块输出
    wire data_out_valid;
    wire signed [17:0] data_out;
    
    // 实例化被测模块
    conv3x3 dut (
        .clk(clk), .rst_n(rst_n),
        .data_in_valid(data_in_valid),
        .data_in_0(data_in_0), .data_in_1(data_in_1), .data_in_2(data_in_2),
        .data_in_3(data_in_3), .data_in_4(data_in_4), .data_in_5(data_in_5),
        .data_in_6(data_in_6), .data_in_7(data_in_7), .data_in_8(data_in_8),
        .weight_en(weight_en), .bias_data(bias_data), .weights_data(weights_data),
        .data_out_valid(data_out_valid), .data_out(data_out)
    );
    
    // 时钟生成 (100MHz)
    always #5 clk = ~clk;
    
    // 定义三帧5x5测试图像
    reg [7:0] frame1 [0:24]; // 5x5 = 25个像素，用一维数组表示
    reg [7:0] frame2 [0:24];
    reg [7:0] frame3 [0:24];
    
    integer i, j;
    
    initial begin
        // 初始化波形文件
        $dumpfile("conv3x3.vcd");
        $dumpvars(0, tb_conv3x3_simple);
        
        // 初始化信号
        clk = 0; rst_n = 1; data_in_valid = 0;
        weight_en = 0; bias_data = 8'sh00; weights_data = 72'b0;
        
        // 生成测试图像
        generate_test_images();
        
        // 复位序列
        #10 rst_n = 0; #20 rst_n = 1; #10;
        
        // 加载权重
        load_weights();
        
        // 处理三帧图像
        process_frame(1); // 帧1: 递增模式
        #100;
        process_frame(2); // 帧2: 棋盘模式
        #100;  
        process_frame(3); // 帧3: 中心突出
        #200;
        
        $display("仿真完成");
        $finish;
    end
    
    // 生成测试图像任务
    task generate_test_images;
    begin
        // 帧1: 从1到25的递增模式
        for (i = 0; i < 25; i = i + 1) begin
            frame1[i] = i + 1;
        end
        
        // 帧2: 棋盘模式 (1和2交替)
        for (i = 0; i < 5; i = i + 1) begin
            for (j = 0; j < 5; j = j + 1) begin
                frame2[i*5+j] = ((i + j) % 2) ? 8'd1 : 8'd2;
            end
        end
        
        // 帧3: 中心为10，边缘为1
        for (i = 0; i < 5; i = i + 1) begin
            for (j = 0; j < 5; j = j + 1) begin
                if (i >= 1 && i <= 3 && j >= 1 && j <= 3) 
                    frame3[i*5+j] = 8'd10;
                else 
                    frame3[i*5+j] = 8'd1;
            end
        end
        
        $display("测试图像生成完成");
    end
    endtask
    
    // 加载权重任务
    task load_weights;
    begin
        @(posedge clk);
        weight_en = 1;
        // 权重模式: [[1,1,1], [1,2,1], [1,1,1]]
        weights_data = 72'h01_01_01_01_02_01_01_01_01;
        @(posedge clk);
        weight_en = 0;
        $display("权重加载完成: %h", weights_data);
    end
    endtask
    
    // 处理单帧图像任务 - 修复后的版本
    task process_frame;
    input integer frame_num;
    integer row, col;
    reg [7:0] current_pixel;
    begin
        $display("开始处理帧 %0d", frame_num);
        
        // 滑动3x3窗口处理5x5图像 (产生3x3=9个输出)
        for (row = 0; row < 3; row = row + 1) begin
            for (col = 0; col < 3; col = col + 1) begin
                @(posedge clk);
                data_in_valid = 1;
                
                // 根据帧号选择对应的图像数据
                case(frame_num)
                    1: current_pixel = frame1[row*5+col];
                    2: current_pixel = frame2[row*5+col];
                    3: current_pixel = frame3[row*5+col];
                endcase
                
                // 提供当前3x3窗口数据
                data_in_0 = (frame_num == 1) ? frame1[(row+0)*5+(col+0)] : 
                            (frame_num == 2) ? frame2[(row+0)*5+(col+0)] : frame3[(row+0)*5+(col+0)];
                data_in_1 = (frame_num == 1) ? frame1[(row+0)*5+(col+1)] : 
                            (frame_num == 2) ? frame2[(row+0)*5+(col+1)] : frame3[(row+0)*5+(col+1)];
                data_in_2 = (frame_num == 1) ? frame1[(row+0)*5+(col+2)] : 
                            (frame_num == 2) ? frame2[(row+0)*5+(col+2)] : frame3[(row+0)*5+(col+2)];
                data_in_3 = (frame_num == 1) ? frame1[(row+1)*5+(col+0)] : 
                            (frame_num == 2) ? frame2[(row+1)*5+(col+0)] : frame3[(row+1)*5+(col+0)];
                data_in_4 = (frame_num == 1) ? frame1[(row+1)*5+(col+1)] : 
                            (frame_num == 2) ? frame2[(row+1)*5+(col+1)] : frame3[(row+1)*5+(col+1)];
                data_in_5 = (frame_num == 1) ? frame1[(row+1)*5+(col+2)] : 
                            (frame_num == 2) ? frame2[(row+1)*5+(col+2)] : frame3[(row+1)*5+(col+2)];
                data_in_6 = (frame_num == 1) ? frame1[(row+2)*5+(col+0)] : 
                            (frame_num == 2) ? frame2[(row+2)*5+(col+0)] : frame3[(row+2)*5+(col+0)];
                data_in_7 = (frame_num == 1) ? frame1[(row+2)*5+(col+1)] : 
                            (frame_num == 2) ? frame2[(row+2)*5+(col+1)] : frame3[(row+2)*5+(col+1)];
                data_in_8 = (frame_num == 1) ? frame1[(row+2)*5+(col+2)] : 
                            (frame_num == 2) ? frame2[(row+2)*5+(col+2)] : frame3[(row+2)*5+(col+2)];
                
                $display("时间%t: 帧%0d 窗口(%0d,%0d) 中心像素=%0d", 
                         $time, frame_num, row, col, data_in_4);
            end
        end
        
        @(posedge clk);
        data_in_valid = 0; // 帧处理结束
        $display("帧 %0d 输入完成", frame_num);
    end
    endtask
    
    // 监控输出
    always @(posedge clk) begin
        if (data_out_valid) begin
            $display("时间%t: 卷积输出 = %0d", $time, data_out);
        end
    end

endmodule