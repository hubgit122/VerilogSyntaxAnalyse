`timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////

`include "constants.v"

module macroblock_layer(
    input               clk,                            //
 
    output  [4*4-1:0]   sub_mb_type,
    output              transform_size_8x8_flag
    );

    reg [7:0]   status;
    reg [3:0]   sub_mb_type_reg[3:0];
    assign      mb_type = mb_type_reg;
    assign      sub_mb_type = {sub_mb_type[3],sub_mb_type[2],sub_mb_type[1],sub_mb_type[0]};
    assign      transform_size_8x8_flag = transform_size_8x8_flag_reg;

    parameter end_status                    = 8'd27;

    wire [255:0] residual_block_cavlc_result;
    wire [4:0]  residual_block_cavlc_bitlen;
    reg  [4:0]  bitlen_event, bitlen_event_;
    reg         PCM_event, PCM_event_;
    reg         skip_4x4_event, skip_4x4_event_;
    reg         skip_mb_event, skip_mb_event_;

    assign      bitlen  = residual_block_cavlc_en? residual_block_cavlc_bitlen : (bitlen_event ^ bitlen_event_);

    assign      done = status == end_status;


    assign  isIntra = (slice_type == `P || slice_type-5 == `P)? {mb_type<=4,mb_type>5}:{1'd0,|mb_type};
    reg     wr_valid;


    residual_block_cavlc residual_block_cavlc_inst(
        .clk                        (clk),
   
        .skip_mb                    (skip_mb || (skip_mb_event ^ skip_mb_event_)),
        .PCM                        (PCM_event^PCM_event_)
    );

    always@(posedge clk or negedge resetn)
    if(!resetn)
        bitlen_event_ <= 0;
    else if(valid)
        bitlen_event_ <= bitlen_event;

    integer i;
    always@(posedge clk or negedge resetn)
    if(!resetn)
        status          <= ini_status;
    else if(valid)
        case(status)
            ini_status:
                begin
                    status          <= status + 1;
					
                    for (i=0; i<27; i = i+1)
                        level[i] <=0;

                    for(i=0 ; i<16 ; i=i+1)
                    begin
                        rem_intra4x4_pred_mode[i]   <= 0;
                        rem_intra8x8_pred_mode[i]   <= 0;
                        mvd_l0[2*i]                 <= 0;
                        mvd_l0[2*i+1]               <= 0;
                        mvd_l1[2*i]                 <= 0;
                        mvd_l1[2*i+1]               <= 0;
                    end

                end

            transform_size_8x8_flag_status:
                if(mb_type == `I_PCM)
                    status <=  PCM_status0;
                else if((mb_type != `I_NxN) && (MbPartPredMode(mb_type, 0, slice_type, transform_size_8x8_flag) != `Intra_16x16) && (NumMbPart(mb_type,slice_type) == 3'd4) )
                    status <= sub_mb_pred_status0;
                else if(mb_type == `I_NxN && transform_8x8_mode_flag)
                begin
                    if(bitstream_valid) // 如果valid, 直接使用, 不需要管使用之后是不是valid, 只要下次使用之前再判断就好了.
                    begin
                        transform_size_8x8_flag_reg <= bitstream[0];
                        bitlen_event <= bitlen_event ^ 5'd1;
                    end

                    status <= mb_pred_status0;
                end

            sub_mb_pred_status0:
                if(xxIdx < 9'd4)
                begin
                    if(bitstream_valid)
                    begin
                        xxIdx <= xxIdx + 1;
                        sub_mb_type_reg[xxIdx] <= ue_value;
                        bitlen_event <= bitlen_event ^ e_bitlen;
                    end
                end
                else
                begin
                    status <= status + 1;
                    xxIdx <= 0;
                end

            sub_mb_pred_status1:
                if(xxIdx < 9'd4)
                    if(|num_ref_idx_l0_active_minus_1 || /*(mb_field_decoding_flag!=field_pic_flag) &&*/ mb_type != `P_8x8ref0 && sub_mb_type[xxIdx] != `B_Direct_8x8 && SubMbPredMode( sub_mb_type[xxIdx], mb_type) != `Pred_L1 )
                    begin
                        if(bitstream_valid)
                        begin
                            xxIdx <= xxIdx + 1;
                            bitlen_event <= bitlen_event ^ te_bitlen;
                            ref_idx_l0[xxIdx[1:0]]   <= te_value;
                        end
                    end
                    else
                        xxIdx <= xxIdx + 1;
                else
                begin
                    status <= status + 1;
                    xxIdx <= 0;
                end

            sub_mb_pred_status2:
                if(xxIdx < 9'd4)
                    if(|num_ref_idx_l1_active_minus_1 || /*(mb_field_decoding_flag!=field_pic_flag) &&*/ sub_mb_type[xxIdx] != `B_Direct_8x8 &&SubMbPredMode(sub_mb_type[xxIdx], mb_type) != `Pred_L0)
                    begin
                        if(bitstream_valid)
                        begin
                            xxIdx <= xxIdx + 1;
                            bitlen_event <= bitlen_event ^ te_bitlen;
                            ref_idx_l1[xxIdx[1:0]]   <= te_value;
                        end
                    end
                    else
                        xxIdx <= xxIdx + 1;
                else
                begin
                    status <= status + 1;
                    xxIdx <= 0;
                end

            sub_mb_pred_status3:        // xxIdx 4:3 mbPartIdx 2:1 subMbPartIdx 0 compIdx;
                if(xxIdx[5:3] < 4)
                    if( sub_mb_type[xxIdx[2:1]] != `B_Direct_8x8 && SubMbPredMode(sub_mb_type[xxIdx[2:1]], mb_type) != `Pred_L1 )
                    begin
                        if(bitstream_valid)
                        begin
                            mvd_l0[xxIdx] <= se_value;
                            bitlen_event <= bitlen_event ^ e_bitlen;
                            xxIdx[5:3] <= xxIdx[5:3] + subMbPartIdxCarry;
                            xxIdx[2:0] <= subMbPartIdxCarry? 3'd0: xxIdx[2:0] + 3'd1;
                        end
                    end
                    else
                    begin
                        xxIdx[5:3] <= xxIdx[5:3] + subMbPartIdxCarry;
                        xxIdx[2:0] <= subMbPartIdxCarry? 3'd0: xxIdx[2:0] + 3'd1;
                    end
                else
                begin
                    status <= status +1;
                    xxIdx <= 0;
                end

            sub_mb_pred_status4:
                if(xxIdx[5:3] < 4)
                    if( sub_mb_type[xxIdx[2:1]] != `B_Direct_8x8 && SubMbPredMode(sub_mb_type[xxIdx[2:1]], mb_type) != `Pred_L0 )
                    begin
                        if(bitstream_valid)
                        begin
                            mvd_l1[xxIdx] <= se_value;
                            bitlen_event <= bitlen_event ^ e_bitlen;
                            xxIdx[5:3] <= xxIdx[5:3] + subMbPartIdxCarry;
                            xxIdx[2:0] <= subMbPartIdxCarry? 3'd0: xxIdx[2:0] + 3'd1;
                        end
                    end
                    else
                    begin
                        xxIdx[5:3] <= xxIdx[5:3] + subMbPartIdxCarry;
                        xxIdx[2:0] <= subMbPartIdxCarry? 3'd0: xxIdx[2:0] + 3'd1;
                    end
                else
                begin
                    status <= coded_block_pattern_status0;
                    xxIdx <= 0;
                end

            mb_pred_status0:
                case(MbPartPredMode(mb_type, 0, slice_type, transform_size_8x8_flag))
                    `Intra_4x4:
                        if(xxIdx < 9'd16)
                            if(bitstream_valid)
                            begin
                                xxIdx <= xxIdx + 1;

                                prev_intra4x4_pred_mode_flag[xxIdx] <= bitstream[0];
                                if(!bitstream[0])
                                begin
                                    bitlen_event <= bitlen_event ^ 5'd4;
                                    rem_intra4x4_pred_mode[xxIdx] <= bitstream[3:1];
                                end
                                else
                                    bitlen_event <= bitlen_event ^ 5'd1;
                            end
                        else
                        begin
                            status <= status + 1;
                            xxIdx <= 0 ;
                        end

                    `Intra_8x8:
                        if(xxIdx < 9'd16)
                            if(bitstream_valid)
                            begin
                                xxIdx <= xxIdx + 1;

                                prev_intra8x8_pred_mode_flag [xxIdx] <= bitstream[0];
                                if(!bitstream[0])
                                begin
                                    bitlen_event <= bitlen_event ^ 5'd4;
                                    rem_intra8x8_pred_mode[xxIdx] <= bitstream[3:1];
                                end
                                else
                                    bitlen_event <= bitlen_event ^ 5'd1;
                            end
                        else
                        begin
                            status <= status + 1;
                            xxIdx <= 0 ;
                        end

                    `Intra_16x16 :
                        status <= status + 1;

                    `Direct:
                        status <= coded_block_pattern_status0;

                    default:
                        status <= status + 2;
                endcase

            mb_pred_status1:
                if((ChromaArrayType=='d1)||(ChromaArrayType=='d2))
                begin
                    if(bitstream_valid)
                    begin
                        intra_chroma_pred_mode <= bitstream[1:0];
                        bitlen_event <= bitlen_event ^ 5'd2;

                        status <= coded_block_pattern_status0;
                    end
                end
                else
                    status <= coded_block_pattern_status0;

            mb_pred_status2:
                if(xxIdx < NumMbPart(mb_type, slice_type))
                    if(|num_ref_idx_l0_active_minus_1 || /*(mb_field_decoding_flag!=field_pic_flag) &&*/ MbPartPredMode ( mb_type, xxIdx, slice_type, transform_size_8x8_flag )!= `Pred_L1)
                    begin
                        if(bitstream_valid)
                        begin
                            xxIdx <= xxIdx + 1;
                            bitlen_event <= bitlen_event ^ te_bitlen;
                            ref_idx_l0[xxIdx[1:0]]   <= te_value;
                        end
                    end
                    else
                        xxIdx <= xxIdx + 1;
                else
                begin
                    status <= status + 1;
                    xxIdx <= 0;
                end

            mb_pred_status3:
                if(xxIdx < NumMbPart(mb_type, slice_type))
                    if((|num_ref_idx_l1_active_minus_1) || /*(mb_field_decoding_flag!=field_pic_flag) &&*/ MbPartPredMode ( mb_type, xxIdx, slice_type, transform_size_8x8_flag )!= `Pred_L0)
                        if(bitstream_valid)
                        begin
                            xxIdx <= xxIdx + 1;
                            bitlen_event <= bitlen_event^te_bitlen;
                            ref_idx_l1[xxIdx[1:0]]   <= te_value;
                        end
                    else
                        xxIdx <= xxIdx + 1;
                else
                begin
                    status <= status + 1;
                    xxIdx <= 0;
                end

            mb_pred_status4:
            begin
                if(MbPartPredMode ( mb_type, xxIdx, slice_type, transform_size_8x8_flag )== `Pred_L1 || bitstream_valid)
                    if(xxIdx == {5'd0, NumMbPart(mb_type, slice_type),1'd0} - 9'd1)
                    begin
                        status <= status + 1;
                        xxIdx <= 0;
                    end
                    else
                        xxIdx <= xxIdx + 1;

                if((MbPartPredMode ( mb_type, xxIdx, slice_type, transform_size_8x8_flag )!= `Pred_L1)&&bitstream_valid)
                begin
                    bitlen_event <= bitlen_event^e_bitlen;
                    mvd_l0[{xxIdx[2:1], 2'b0, xxIdx[0]}]  <= se_value;
                end
            end

            mb_pred_status5:
            begin
                if(MbPartPredMode ( mb_type, xxIdx, slice_type, transform_size_8x8_flag )== `Pred_L0 || bitstream_valid)
                    if(xxIdx == {5'd0, NumMbPart(mb_type, slice_type),1'd0} - 9'd1)
                    begin
                        status <= coded_block_pattern_status0;
                        xxIdx <= 0;
                    end
                    else
                        xxIdx <= xxIdx + 1;

                if((MbPartPredMode ( mb_type, xxIdx, slice_type, transform_size_8x8_flag )!= `Pred_L0)&&bitstream_valid)
                begin
                    mvd_l1[{xxIdx[2:1], 2'b0, xxIdx[0]}]  <= se_value;
                    bitlen_event <= bitlen_event^e_bitlen;
                end
            end

            PCM_status0:        //要求首先字节对齐, 假设解码开始的时候是字节对齐的, 那么只要看解码长度就好了.
                if(bitstream_valid)
                begin
                    if(decoded_bitlen[2:0])       //看低三位
                        bitlen_event <= bitlen_event ^ (5'd8 - {2'd0, decoded_bitlen[2:0]});
                    status <= status + 1;
                end

            PCM_status1:
                    if(bitstream_valid)
                    begin
                        xxIdx <= (xxIdx == 9'd255)? xxIdx + 9'd1:9'd0;

                        if(xxIdx == 9'd255)
                        begin
                            if( separate_colour_plane_flag || chroma_format_idc ==0)
                                status <= end_status;
                            else
                                status <= status + 1;
                        end

                        pcm_sample_luma[xxIdx]  <= ue_value;
                        bitlen_event  <= bitlen_event ^ e_bitlen;
                    end

            PCM_status2:
                if(xxIdx == {(chroma_format_idc==2'd1)? 9'd64: (chroma_format_idc==2'd2)? 9'd128: 9'd256, 1'b0})
                begin
                    PCM_event <= ~PCM_event;
                    status <= end_status;
                    xxIdx <= 0;
                end
                else
                    if(bitstream_valid)
                    begin
                        xxIdx <= xxIdx + 1;

                        pcm_sample_chroma[xxIdx]  <= ue_value;
                        bitlen_event  <= bitlen_event ^ e_bitlen;
                    end

            coded_block_pattern_status0:
                if(MbPartPredMode(mb_type, 0, slice_type, transform_size_8x8_flag_reg) != `Intra_16x16)
                    status <= status +1;
                else
                    status <= status +2;

            coded_block_pattern_status1:
                if(bitstream_valid)
                begin
                    coded_block_pattern <= me_value;
                    bitlen_event        <= bitlen_event ^ e_bitlen;

                    if((CodedBlockPatternLuma(me_value, mb_type, slice_type) > 0)
                    && (transform_8x8_mode_flag) && (mb_type!=`I_NxN)
                    &&( MbPartPredMode(mb_type, 0, slice_type, transform_size_8x8_flag_reg) == `Intra_16x16 || NumMbPart(mb_type, slice_type) == 3'd4 ||
                        ((NumSubMbPart(sub_mb_type[0],slice_type)==3'd1) && (NumSubMbPart(sub_mb_type[1],slice_type)==3'd1) && (NumSubMbPart(sub_mb_type[2],slice_type)==3'd1) && (NumSubMbPart(sub_mb_type[3],slice_type)==3'd1))
                       )
                    )
                        status <= status + 1;
                    else
                        status <= status +2;
                end

            coded_block_pattern_status2:
                if(bitstream_valid)
                begin
                    transform_size_8x8_flag_reg <= bitstream[0];
                    bitlen_event <= bitlen_event ^ 5'd1;
                    status <= status + 1;
                end


            coded_block_pattern_status3:
                if((CodedBlockPatternLuma(coded_block_pattern, mb_type,slice_type) > 0) || CodedBlockPatternChroma(coded_block_pattern, mb_type,slice_type) > 0 || MbPartPredMode(mb_type_reg, 0, slice_type, transform_size_8x8_flag_reg) == `Intra_16x16 )
                    status <= status + 1;
                else
                begin
                    status <= end_status;
                    skip_mb_event <= ~skip_mb_event;
                end

            mb_qp_delta_status:
                if(bitstream_valid)
                begin
                    mb_qp_delta <= se_value;
                    bitlen_event <= bitlen_event ^ e_bitlen;
                    status <= status + 1;
                end

            residual_status0 :
                if(!residual_block_cavlc_en)
                begin
                    if(MbPartPredMode(mb_type, 0, slice_type, transform_size_8x8_flag))
                    begin
                        residual_block_cavlc_en <= 1;
                        startIdx                <= 4'd0;
                        endIdx                  <= 4'd15;
//                        maxNumCoeff_minus_1     <= 4'd15;
                    end
                    else
                    begin
                        status <= status + 1;
                        xxIdx <= xxIdx + 1;     // TO-DO 不管怎样, 给LumaDC留出位置.
                    end
                end
                else
                    if(residual_block_cavlc_done)
                    begin
                        xxIdx                   <= xxIdx + 1;
                        level[xxIdx]            <= residual_block_cavlc_result;
                        residual_block_cavlc_en <= 0;
                        status                  <= status +1;
                        LumaDC                  <= 1;
                    end

            residual_status1 :          // LumaAC or Luma
                if(!residual_block_cavlc_en)
                    if(CodedBlockPatternLuma(coded_block_pattern, mb_type,slice_type) & (1<<((xxIdx-1)>>2)))
                    begin
                        residual_block_cavlc_en <= 1;
                        startIdx                <= 4'd0;
                        endIdx                  <= MbPartPredMode(mb_type, 0, slice_type, transform_size_8x8_flag)? 4'd14:4'd15;
//                        maxNumCoeff_minus_1     <= MbPartPredMode(mb_type, 0, slice_type, transform_size_8x8_flag)? 4'd14:4'd15;
                    end
                    else
                    begin
                        level[xxIdx]            <= 0;
                        skip_4x4_event          <= ~skip_4x4_event;
                        xxIdx                   <= xxIdx +1;
                        status                  <= (xxIdx == 4'd15)? status + 8'd1 : status;
                    end
                else
                    if(residual_block_cavlc_done)
                    begin
                        level[xxIdx]            <= residual_block_cavlc_result;
                        residual_block_cavlc_en <= 0;
                        xxIdx                   <= xxIdx + 8'd1;
                        status                  <= (xxIdx == 4'd15)? status + 8'd1 : status;
                    end

            residual_status2,
            residual_status3:              //CbCr的DC颜色
                if(!residual_block_cavlc_en)
                    if(CodedBlockPatternChroma(coded_block_pattern, mb_type,slice_type) & 3)
                    begin
                        residual_block_cavlc_en <= 1;
                        startIdx                <= 4'd0;
                        endIdx                  <= 4'd3;
//                        maxNumCoeff_minus_1     <= 4'd3;
                    end
                    else
                    begin
                        level[xxIdx]            <= 0;     //这次的结果只有四个系数, 知道就好了
                        xxIdx                   <= xxIdx + 1;
                        status                  <= status +1;
                    end
                else
                    if(residual_block_cavlc_done)
                    begin
                        level[xxIdx]            <= residual_block_cavlc_result;     //文档写的是ChromaLevel, 我觉得下标不统一, 还是全放在level里吧.     //这次的结果只有四个系数, 知道就好了
                        residual_block_cavlc_en <= 0;
                        xxIdx                   <= xxIdx + 1;
                        status                  <= status +1;
                    end

            residual_status4:              //CbCr的AC颜色
                if(!residual_block_cavlc_en)
                    if(CodedBlockPatternChroma(coded_block_pattern, mb_type,slice_type) & 2)
                    begin
                        residual_block_cavlc_en <= 1;
                        startIdx                <= 4'd0;
                        endIdx                  <= 4'd14;
//                        maxNumCoeff_minus_1     <= 4'd14;
                    end
                    else
                    begin
                        level[xxIdx]            <= 0;     //这次的结果有15个系数
                        skip_4x4_event          <= ~skip_4x4_event;
                        xxIdx                   <= xxIdx + 1;
                        status                  <= (xxIdx == 9'd26)? end_status: status;
                    end
                else
                    if(residual_block_cavlc_done)
                    begin
                        level[xxIdx]            <= residual_block_cavlc_result;     //这次的结果有15个系数
                        residual_block_cavlc_en <= 0;
                        xxIdx                   <= xxIdx + 1;
                        status                  <= (xxIdx == 9'd26)? end_status: status;
                    end


            end_status:
                status <= ini_status;

            default:
                status <= ini_status;
        endcase

    function [2:0] NumSubMbPart;
        input   [3:0]   sub_mb_type;
        input   [3:0]   slice_type;
        reg   [3:0] slice_type_;
        begin
            slice_type_ = (slice_type >= 5)? slice_type - 4'd5 : slice_type;
            case(slice_type_)
                `P:
                    case(sub_mb_type)
                        `P_L0_8x8: NumSubMbPart = 3'd1;
                        `P_L0_8x4: NumSubMbPart = 3'd2;
                        `P_L0_4x8: NumSubMbPart = 3'd2;
                        `P_L0_4x4: NumSubMbPart = 3'd4;
                        default  :NumSubMbPart = 3'bx;
                    endcase

                `B:
                    case(sub_mb_type)
                        `B_Direct_8x8 :NumSubMbPart = 3'd4;
                        `B_L0_8x8 :NumSubMbPart = 3'd1;
                        `B_L1_8x8 :NumSubMbPart = 3'd1;
                        `B_Bi_8x8 :NumSubMbPart = 3'd1;
                        `B_L0_8x4 :NumSubMbPart = 3'd2;
                        `B_L0_4x8 :NumSubMbPart = 3'd2;
                        `B_L1_8x4 :NumSubMbPart = 3'd2;
                        `B_L1_4x8 :NumSubMbPart = 3'd2;
                        `B_Bi_8x4 :NumSubMbPart = 3'd2;
                        `B_Bi_4x8 :NumSubMbPart = 3'd2;
                        `B_L0_4x4 :NumSubMbPart = 3'd4;
                        `B_L1_4x4 :NumSubMbPart = 3'd4;
                        `B_Bi_4x4 :NumSubMbPart = 3'd4;
                        default  :NumSubMbPart = 3'bx;

                    endcase
                default:
                    NumSubMbPart = 3'bx;
            endcase
        end
    endfunction

    function [1:0] MbPartPredMode;
        input [4:0] mb_type;
        input       index;
        input [3:0] slice_type;
        reg   [3:0] slice_type_;
        input       transform_size_8x8_flag;
        begin
            slice_type_ = (slice_type >= 5)? slice_type - 4'd5 : slice_type;
            case(slice_type_)
                `I:  MbPartPredMode = index ? 2'bx : (mb_type? ((mb_type== `I_PCM)? 2'bx : `Intra_16x16) : (transform_size_8x8_flag? `Intra_8x8 : `Intra_4x4 ));

                `SI: MbPartPredMode = mb_type? (index ? 2'bx : ((mb_type-1)? ((mb_type== `I_PCM+1)? 2'bx : `Intra_16x16) : (transform_size_8x8_flag? `Intra_8x8 : `Intra_4x4 ))) :`Intra_4x4;

                `P,`SP:
                    if(mb_type <= 5'd4)
                        MbPartPredMode = (mb_type == 5'd3|| mb_type == 5'd4)? 2'bx: `Pred_L0;
                    else
                        MbPartPredMode = index ? 2'bx : ((mb_type-5)? (((mb_type-5)== `I_PCM)? 2'bx : `Intra_16x16) : (transform_size_8x8_flag? `Intra_8x8 : `Intra_4x4 ));

                `B:  case(mb_type)
                        `B_Direct_16x16  :MbPartPredMode = index ? 2'bx : `Direct ;
                        `B_L0_16x16      :MbPartPredMode = index ? 2'bx : `Pred_L0 ;
                        `B_L1_16x16      :MbPartPredMode = index ? 2'bx : `Pred_L1 ;
                        `B_Bi_16x16      :MbPartPredMode = index ? 2'bx : `BiPred ;
                        `B_L0_L0_16x8    :MbPartPredMode = index ? `Pred_L0 : `Pred_L0 ;
                        `B_L0_L0_8x16    :MbPartPredMode = index ? `Pred_L0 : `Pred_L0 ;
                        `B_L1_L1_16x8    :MbPartPredMode = index ? `Pred_L1 : `Pred_L1 ;
                        `B_L1_L1_8x16    :MbPartPredMode = index ? `Pred_L1 : `Pred_L1 ;
                        `B_L0_L1_16x8    :MbPartPredMode = index ? `Pred_L1 : `Pred_L0 ;
                        `B_L0_L1_8x16    :MbPartPredMode = index ? `Pred_L1 : `Pred_L0 ;
                        `B_L1_L0_16x8    :MbPartPredMode = index ? `Pred_L0 : `Pred_L1 ;
                        `B_L1_L0_8x16    :MbPartPredMode = index ? `Pred_L0 : `Pred_L1 ;
                        `B_L0_Bi_16x8    :MbPartPredMode = index ? `BiPred : `Pred_L0 ;
                        `B_L0_Bi_8x16    :MbPartPredMode = index ? `BiPred : `Pred_L0 ;
                        `B_L1_Bi_16x8    :MbPartPredMode = index ? `BiPred : `Pred_L1 ;
                        `B_L1_Bi_8x16    :MbPartPredMode = index ? `BiPred : `Pred_L1 ;
                        `B_Bi_L0_16x8    :MbPartPredMode = index ? `Pred_L0 : `BiPred ;
                        `B_Bi_L0_8x16    :MbPartPredMode = index ? `Pred_L0 : `BiPred ;
                        `B_Bi_L1_16x8    :MbPartPredMode = index ? `Pred_L1 : `BiPred ;
                        `B_Bi_L1_8x16    :MbPartPredMode = index ? `Pred_L1 : `BiPred ;
                        `B_Bi_Bi_16x8    :MbPartPredMode = index ? `BiPred : `BiPred ;
                        `B_Bi_Bi_8x16    :MbPartPredMode = index ? `BiPred : `BiPred ;
                        default         :MbPartPredMode = 2'bx;
                    endcase

                default:
                    MbPartPredMode = 2'bx;
            endcase
        end
    endfunction

    function [1:0] SubMbPredMode;
        input [3:0] sub_mb_type;
        input [3:0] slice_type;
        reg   [3:0] slice_type_;
        begin
            slice_type_ = (slice_type >= 5)? slice_type - 4'd5 : slice_type;

            case(slice_type_)
                `B:
                    case(sub_mb_type)
                        `B_Direct_8x8   : SubMbPredMode = `Direct;
                        `B_L0_8x8       : SubMbPredMode = `Pred_L0;
                        `B_L1_8x8       : SubMbPredMode = `Pred_L1;
                        `B_Bi_8x8       : SubMbPredMode = `BiPred;
                        `B_L0_8x4       : SubMbPredMode = `Pred_L0;
                        `B_L0_4x8       : SubMbPredMode = `Pred_L0;
                        `B_L1_8x4       : SubMbPredMode = `Pred_L1;
                        `B_L1_4x8       : SubMbPredMode = `Pred_L1;
                        `B_Bi_8x4       : SubMbPredMode = `BiPred;
                        `B_Bi_4x8       : SubMbPredMode = `BiPred;
                        `B_L0_4x4       : SubMbPredMode = `Pred_L0;
                        `B_L1_4x4       : SubMbPredMode = `Pred_L1;
                        `B_Bi_4x4       : SubMbPredMode = `BiPred;

                        default         : SubMbPredMode = 2'bx;
                    endcase
                `P:         SubMbPredMode = `Pred_L0;
                default:    SubMbPredMode = 2'bx;
            endcase
        end
    endfunction

    function [2:0] NumMbPart;
        input [4:0] mb_type;
        input [3:0] slice_type;
        reg   [3:0] slice_type_;
        begin
            slice_type_ = (slice_type >= 5)? slice_type - 4'd5 : slice_type;
            case(slice_type_)
                `P,`SP :
                    case(mb_type)
                        `P_L0_16x16      : NumMbPart = 3'd1;
                        `P_L0_L0_16x8    : NumMbPart = 3'd2;
                        `P_L0_L0_8x16    : NumMbPart = 3'd2;
                        `P_8x8           : NumMbPart = 3'd4;
                        `P_8x8ref0       : NumMbPart = 3'd4;

                        default          : NumMbPart = 3'bx;
                    endcase
                `B:
                    if(mb_type == 5'd0)
                        NumMbPart = 3'bx;
                    else if((mb_type == 5'd1)||(mb_type == 5'd2)||(mb_type == 5'd3))
                        NumMbPart = 3'd1;
                    else if(mb_type == 5'd22)
                        NumMbPart = 3'd4;
                    else if((mb_type >= 5'd4)&&(mb_type <= 5'd21))
                        NumMbPart = 3'd2;
                    else
                        NumMbPart = 3'bx;

                default:
                    NumMbPart = 3'bx;
            endcase
        end
    endfunction

    function [3:0] CodedBlockPatternLuma;
        input [5:0] coded_block_pattern;
        input [4:0] mb_type;
        input [3:0] slice_type;
        reg   [3:0] slice_type_;
        begin
            slice_type_ = (slice_type >= 5)? slice_type - 4'd5 : slice_type;
            case(slice_type_)
                `I:
                    case(mb_type)
                        `I_NxN         :CodedBlockPatternLuma = coded_block_pattern[3:0] & 4'b1111;
                        `I_16x16_0_0_0,`I_16x16_0_0_0 :CodedBlockPatternLuma = 0;
                        `I_16x16_1_0_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_2_0_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_3_0_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_0_1_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_1_1_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_2_1_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_3_1_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_0_2_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_1_2_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_2_2_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_3_2_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_0_0_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_1_0_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_2_0_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_3_0_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_0_1_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_1_1_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_2_1_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_3_1_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_0_2_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_1_2_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_2_2_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_3_2_1 :CodedBlockPatternLuma = 4'd15;
                        `I_PCM         :CodedBlockPatternLuma = 4'bx;
                        default       :CodedBlockPatternLuma = 4'bx;
                    endcase

                `SI:
                    if(!mb_type)
                        CodedBlockPatternLuma = coded_block_pattern[3:0] & 4'b1111;
                    else case(mb_type-1)
                        `I_NxN         :CodedBlockPatternLuma = coded_block_pattern[3:0] & 4'b1111;
                        `I_16x16_0_0_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_1_0_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_2_0_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_3_0_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_0_1_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_1_1_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_2_1_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_3_1_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_0_2_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_1_2_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_2_2_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_3_2_0 :CodedBlockPatternLuma = 4'd0;
                        `I_16x16_0_0_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_1_0_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_2_0_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_3_0_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_0_1_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_1_1_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_2_1_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_3_1_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_0_2_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_1_2_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_2_2_1 :CodedBlockPatternLuma = 4'd15;
                        `I_16x16_3_2_1 :CodedBlockPatternLuma = 4'd15;
                        `I_PCM         :CodedBlockPatternLuma = 4'bx;
                        default       :CodedBlockPatternLuma = 4'bx;
                    endcase

                `B:
                    CodedBlockPatternLuma = coded_block_pattern[3:0] & 4'b1111;

                default:
                    CodedBlockPatternLuma = 4'bx;
            endcase
        end
    endfunction

    function [1:0] CodedBlockPatternChroma;
        input [5:0] coded_block_pattern;
        input [4:0] mb_type;
        input [3:0] slice_type;
        reg   [3:0] slice_type_;
        begin
            slice_type_ = (slice_type >= 5)? slice_type - 4'd5 : slice_type;

            case(slice_type_)
                `I:
                    case(mb_type)
                        `I_NxN         :CodedBlockPatternChroma = coded_block_pattern[5:4];
                        `I_16x16_0_0_0 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_1_0_0 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_2_0_0 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_3_0_0 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_0_1_0 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_1_1_0 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_2_1_0 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_3_1_0 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_0_2_0 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_1_2_0 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_2_2_0 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_3_2_0 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_0_0_1 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_1_0_1 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_2_0_1 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_3_0_1 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_0_1_1 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_1_1_1 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_2_1_1 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_3_1_1 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_0_2_1 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_1_2_1 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_2_2_1 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_3_2_1 :CodedBlockPatternChroma = 2'd2;
                        `I_PCM         :CodedBlockPatternChroma = 2'bx;

                        default       :CodedBlockPatternChroma = 2'bx;
                    endcase

                `SI:
                    if(!mb_type)
                        CodedBlockPatternChroma = coded_block_pattern[5:4];
                    else case(mb_type-1)
                        `I_NxN         :CodedBlockPatternChroma = coded_block_pattern[5:4];
                        `I_16x16_0_0_0 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_1_0_0 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_2_0_0 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_3_0_0 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_0_1_0 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_1_1_0 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_2_1_0 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_3_1_0 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_0_2_0 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_1_2_0 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_2_2_0 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_3_2_0 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_0_0_1 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_1_0_1 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_2_0_1 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_3_0_1 :CodedBlockPatternChroma = 2'd0;
                        `I_16x16_0_1_1 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_1_1_1 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_2_1_1 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_3_1_1 :CodedBlockPatternChroma = 2'd1;
                        `I_16x16_0_2_1 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_1_2_1 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_2_2_1 :CodedBlockPatternChroma = 2'd2;
                        `I_16x16_3_2_1 :CodedBlockPatternChroma = 2'd2;
                        `I_PCM         :CodedBlockPatternChroma = 2'bx;
                        default       :CodedBlockPatternChroma = 2'bx;
                    endcase

                `B:  CodedBlockPatternChroma = coded_block_pattern[5:4];

                default:    CodedBlockPatternChroma = 2'bx;
            endcase
        end
    endfunction
endmodule