import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/design_tokens.dart';

/// Marketing Stickers & Overlays — 10/10 quality for catalog and video

class MarketingSticker {
  const MarketingSticker({
    required this.id,
    required this.text,
    required this.emoji,
    required this.category,
    required this.color,
  });

  final String id;
  final String text;
  final String emoji;
  final String category;
  final Color color;

  static List<MarketingSticker> get all => [
    MarketingSticker(id: 'shop_now', text: '🛒 SHOP NOW', emoji: '🛒', category: 'Sale', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'on_sale', text: '🔥 ON SALE', emoji: '🔥', category: 'Sale', color: Color(0xFFe63946)),
    MarketingSticker(id: 'big_sale', text: '🏷️ BIG SALE', emoji: '🏷️', category: 'Sale', color: Color(0xFFfbbf24)),
    MarketingSticker(id: 'discount', text: '💰 DISCOUNT', emoji: '💰', category: 'Sale', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'clearance', text: '⚡ CLEARANCE', emoji: '⚡', category: 'Sale', color: Color(0xFFe63946)),
    MarketingSticker(id: 'flash_deal', text: '⚡ FLASH DEAL', emoji: '⚡', category: 'Sale', color: Color(0xFFe63946)),
    MarketingSticker(id: 'mega_sale', text: '🎉 MEGA SALE', emoji: '🎉', category: 'Sale', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'special_offer', text: '🎁 SPECIAL OFFER', emoji: '🎁', category: 'Sale', color: Color(0xFFfbbf24)),
    MarketingSticker(id: 'price_drop', text: '📉 PRICE DROP', emoji: '📉', category: 'Sale', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'limited_time', text: '⏰ LIMITED TIME', emoji: '⏰', category: 'Sale', color: Color(0xFFe63946)),
    MarketingSticker(id: 'buy_one_get_one', text: '🎁 BUY 1 GET 1', emoji: '🎁', category: 'Sale', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'free_delivery', text: '🚚 FREE DELIVERY', emoji: '🚚', category: 'Delivery', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'new_arrival', text: '✨ NEW ARRIVAL', emoji: '✨', category: 'New', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'just_in', text: '🆕 JUST IN', emoji: '🆕', category: 'New', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'fresh_stock', text: '📦 FRESH STOCK', emoji: '📦', category: 'New', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'trending', text: '📈 TRENDING', emoji: '📈', category: 'Trend', color: Color(0xFFe63946)),
    MarketingSticker(id: 'hot_item', text: '🔥 HOT ITEM', emoji: '🔥', category: 'Trend', color: Color(0xFFe63946)),
    MarketingSticker(id: 'bestseller', text: '⭐ BESTSELLER', emoji: '⭐', category: 'Trend', color: Color(0xFFfbbf24)),
    MarketingSticker(id: 'top_rated', text: '🏆 TOP RATED', emoji: '🏆', category: 'Trend', color: Color(0xFFfbbf24)),
    MarketingSticker(id: 'limited_stock', text: '⚠️ LIMITED STOCK', emoji: '⚠️', category: 'Urgency', color: Color(0xFFe63946)),
    MarketingSticker(id: 'last_few', text: '🔴 LAST FEW', emoji: '🔴', category: 'Urgency', color: Color(0xFFe63946)),
    MarketingSticker(id: 'selling_fast', text: '💨 SELLING FAST', emoji: '💨', category: 'Urgency', color: Color(0xFFe63946)),
    MarketingSticker(id: 'while_stocks_last', text: '⏳ WHILE STOCKS LAST', emoji: '⏳', category: 'Urgency', color: Color(0xFFe63946)),
    MarketingSticker(id: 'exclusive', text: '💎 EXCLUSIVE', emoji: '💎', category: 'Premium', color: Color(0xFFfbbf24)),
    MarketingSticker(id: 'premium', text: '👑 PREMIUM', emoji: '👑', category: 'Premium', color: Color(0xFFfbbf24)),
    MarketingSticker(id: 'quality', text: '✅ QUALITY', emoji: '✅', category: 'Trust', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'verified', text: '✓ VERIFIED', emoji: '✓', category: 'Trust', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'genuine', text: '🔒 GENUINE', emoji: '🔒', category: 'Trust', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'authentic', text: '💯 AUTHENTIC', emoji: '💯', category: 'Trust', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'warranty', text: '🛡️ WARRANTY', emoji: '🛡️', category: 'Trust', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'returnable', text: '↩️ RETURNABLE', emoji: '↩️', category: 'Trust', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'cash_on_delivery', text: '💵 CASH ON DELIVERY', emoji: '💵', category: 'Payment', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'mobile_money', text: '📱 MOBILE MONEY', emoji: '📱', category: 'Payment', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'installments', text: '💳 INSTALLMENTS', emoji: '💳', category: 'Payment', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'bnpl', text: '🏦 BNPL', emoji: '🏦', category: 'Payment', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'contact_us', text: '📞 CONTACT US', emoji: '📞', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'dm_to_order', text: '💬 DM TO ORDER', emoji: '💬', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'link_in_bio', text: '🔗 LINK IN BIO', emoji: '🔗', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'swipe_up', text: '👆 SWIPE UP', emoji: '👆', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'order_now', text: '🛍️ ORDER NOW', emoji: '🛍️', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'shop_link', text: '🛒 SHOP LINK IN BIO', emoji: '🛒', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'whatsapp_order', text: '📲 WHATSAPP TO ORDER', emoji: '📲', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'call_now', text: '📞 CALL NOW', emoji: '📞', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'visit_shop', text: '🏪 VISIT OUR SHOP', emoji: '🏪', category: 'CTA', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'follow_us', text: '👥 FOLLOW US', emoji: '👥', category: 'Social', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'tag_friends', text: '🏷️ TAG A FRIEND', emoji: '🏷️', category: 'Social', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'share_post', text: '📤 SHARE THIS POST', emoji: '📤', category: 'Social', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'comment_below', text: '💬 COMMENT BELOW', emoji: '💬', category: 'Social', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'save_post', text: '🔖 SAVE THIS POST', emoji: '🔖', category: 'Social', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'double_tap', text: '❤️ DOUBLE TAP IF YOU LOVE IT', emoji: '❤️', category: 'Social', color: Color(0xFFe63946)),
    MarketingSticker(id: 'uganda', text: '🇺🇬 UGANDA', emoji: '🇺🇬', category: 'Location', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'kampala', text: '📍 KAMPALA', emoji: '📍', category: 'Location', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'east_africa', text: '🌍 EAST AFRICA', emoji: '🌍', category: 'Location', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'made_in_uganda', text: '🇺🇬 MADE IN UGANDA', emoji: '🇺🇬', category: 'Location', color: Color(0xFF0EBE7E)),
    MarketingSticker(id: 'proudly_ugandan', text: '🇺🇬 PROUDLY UGANDAN', emoji: '🇺🇬', category: 'Location', color: Color(0xFF0EBE7E)),
  ];
}

/// Animated text overlay for video using FFmpeg drawtext
class AnimatedTextOverlay {
  static String buildAnimatedDrawtext({
    required String text,
    required String fontPath,
    required double fontSize,
    required String color,
    required String borderColor,
    required double borderWidth,
    required String position,
    String animation = 'fade',
    double startTime = 0,
    double duration = 3,
    double canvasWidth = 1080,
    double canvasHeight = 1920,
  }) {
    final escaped = _escapeDrawtext(text);
    final x = '(w-text_w)/2';
    final y = position == 'top'
        ? 'h*0.08'
        : position == 'center'
            ? '(h-text_h)/2'
            : 'h*0.75';

    String enableExpr = "between(t,$startTime,${startTime + duration})";

    switch (animation) {
      case 'fade':
        return "drawtext=fontfile='$fontPath':text='$escaped':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y:alpha='if(lt(t,$startTime),0,if(lt(t,${startTime + 0.5}),(t-$startTime)/0.5,if(lt(t,${startTime + duration - 0.5}),1,(${startTime + duration}-t)/0.5)))':enable='$enableExpr'";
      case 'slideup':
        return "drawtext=fontfile='$fontPath':text='$escaped':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y-$y*if(lt(t,$startTime),1,if(lt(t,${startTime + 0.4}),(1-(t-$startTime)/0.4),0)):enable='$enableExpr'";
      case 'slideleft':
        return "drawtext=fontfile='$fontPath':text='$escaped':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x-(w+text_w)*if(lt(t,$startTime),1,if(lt(t,${startTime + 0.4}),(1-(t-$startTime)/0.4),0)):y=$y:enable='$enableExpr'";
      case 'pop':
        final scaleExpr = "if(lt(t,$startTime),0,if(lt(t,${startTime + 0.3}),1.5-0.5*(${startTime + 0.3}-t)/0.3,1))";
        return "drawtext=fontfile='$fontPath':text='$escaped':fontsize=$fontSize*$scaleExpr:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y:enable='$enableExpr'";
      case 'bounce':
        return "drawtext=fontfile='$fontPath':text='$escaped':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y+100*abs(sin(3.14159*(t-$startTime)))*if(lt(t,$startTime),0,if(gt(t,${startTime + 2}),0,1)):enable='$enableExpr'";
      default:
        return "drawtext=fontfile='$fontPath':text='$escaped':fontsize=$fontSize:fontcolor=$color:borderw=$borderWidth:bordercolor=$borderColor:x=$x:y=$y:alpha='if(lt(t,$startTime),0,if(lt(t,${startTime + 0.3}),(t-$startTime)/0.3,1))':enable='$enableExpr'";
    }
  }

  static String _escapeDrawtext(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll("'", '\u2019')
        .replaceAll('%', '\\%')
        .replaceAll(',', '\\,');
  }
}

/// Video Ad Builder with Stickers and Animated Text
class VideoAdBuilderWithStickers {
  static const double perImage = 5.0;

  static String buildCommand({
    required List<String> imagePaths,
    required String musicPath,
    required String fontPath,
    required String productName,
    required String price,
    required String outputPath,
    String? stickerText,
    String animation = 'fade',
  }) {
    const w = 1080, h = 1920, fps = 30;
    const fadeDur = 0.5;

    final inputs = imagePaths
        .map((p) => "-loop 1 -t $perImage -i '$p'")
        .join(' ');

    final scaleFilters = List.generate(imagePaths.length, (i) =>
        "[$i:v]scale=$w:$h:force_original_aspect_ratio=decrease,"
        "pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=$fps[v$i]"
    ).join(';');

    final offset1 = perImage - fadeDur;
    final offset2 = offset1 + perImage - fadeDur;
    final totalDur = offset2 + perImage - fadeDur;

    String stickerFilter;
    if (stickerText != null && stickerText.isNotEmpty) {
      final nameOverlay = AnimatedTextOverlay.buildAnimatedDrawtext(
        text: productName,
        fontPath: fontPath,
        fontSize: 72,
        color: 'white',
        borderColor: 'black',
        borderWidth: 4,
        position: 'bottom',
        animation: animation,
        startTime: 0.5,
        duration: 4,
      );
      final priceOverlay = AnimatedTextOverlay.buildAnimatedDrawtext(
        text: price,
        fontPath: fontPath,
        fontSize: 96,
        color: '#FFD700',
        borderColor: 'black',
        borderWidth: 4,
        position: 'bottom',
        animation: 'pop',
        startTime: 1.0,
        duration: 3.5,
      );
      stickerFilter = ";[v2]$nameOverlay[x3];[x3]$priceOverlay[vout]";
    } else {
      stickerFilter = ";[v2]drawtext=fontfile='$fontPath':text='$productName':fontsize=72:fontcolor=white:borderw=4:bordercolor=black:x=(w-text_w)/2:y=h-380[x3];[x3]drawtext=fontfile='$fontPath':text='$price':fontsize=96:fontcolor=#FFD700:borderw=4:bordercolor=black:x=(w-text_w)/2:y=h-260[vout]";
    }

    final filter = "$scaleFilters;"
        "[v0][v1]xfade=transition=fade:duration=$fadeDur:offset=$offset1[x1];"
        "[x1][v2]xfade=transition=fade:duration=$fadeDur:offset=$offset2[x2]"
        "$stickerFilter";

    return "-y $inputs -i '$musicPath' "
        "-filter_complex \"$filter\" "
        "-map \"[vout]\" -map ${imagePaths.length}:a "
        "-c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p "
        "-c:a aac -b:a 128k -shortest -t ${totalDur.ceil()} "
        "'$outputPath'";
  }

  static Future<bool> generate({
    required List<String> imagePaths,
    required String musicPath,
    required String fontPath,
    required String productName,
    required String price,
    required String outputPath,
    String? stickerText,
    String animation = 'fade',
    required void Function(double progress) onProgress,
  }) async {
    final cmd = buildCommand(
      imagePaths: imagePaths,
      musicPath: musicPath,
      fontPath: fontPath,
      productName: productName,
      price: price,
      outputPath: outputPath,
      stickerText: stickerText,
      animation: animation,
    );

    final totalMs = (imagePaths.length * perImage * 1000).toInt();
    final session = await FFmpegKit.executeAsync(
      cmd,
      null,
      null,
      (stats) {
        final progress = (stats.getTime() / totalMs).clamp(0.0, 1.0);
        onProgress(progress);
      },
    );

    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }
}

/// Share Helper
class ShareHelper {
  static Future<void> shareImage(String path, {String? text}) async {
    await Share.shareXFiles(
      [XFile(path)],
      text: text ?? 'Check out this product on Soko24!',
    );
  }

  static Future<void> shareVideo(String path, {String? text}) async {
    await Share.shareXFiles(
      [XFile(path)],
      text: text ?? 'Check out this product on Soko24!',
    );
  }

  static Future<void> sharePdf(String path, {String? text}) async {
    await Share.shareXFiles(
      [XFile(path)],
      text: text ?? 'My product catalog on Soko24',
    );
  }

  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<String> extractFont() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/Montserrat-Bold.ttf');
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/fonts/Montserrat-Bold.ttf');
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    return file.path;
  }
}

/// Sticker Palette Widget
class StickerPalette extends StatelessWidget {
  const StickerPalette({
    super.key,
    required this.onStickerSelected,
    this.selectedId,
  });

  final void Function(MarketingSticker sticker) onStickerSelected;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final stickers = MarketingSticker.all;
    final categories = stickers.map((s) => s.category).toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add Sticker', style: DesignTokens.textTitle),
        const SizedBox(height: DesignTokens.spaceSm),
        ...categories.map((cat) {
          final catStickers = stickers.where((s) => s.category == cat).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat, style: DesignTokens.textSmallBold),
              const SizedBox(height: DesignTokens.spaceXs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: catStickers.map((s) {
                  final isSelected = selectedId == s.id;
                  return GestureDetector(
                    onTap: () => onStickerSelected(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? s.color
                            : s.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? s.color : s.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        s.text,
                        style: TextStyle(
                          color: isSelected ? Colors.white : s.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
            ],
          );
        }),
      ],
    );
  }
}
