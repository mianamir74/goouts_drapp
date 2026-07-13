import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../support/my_tickets_button.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class MessageDetailScreen extends StatefulWidget {
  final String userId;
  final String messageId;
  final String senderName;
  final String title;
  final String body;
  final String createdAtLabel;
  final bool isRead;
  final String imageUrl;
  final String imageName;
  final String attachmentUrl;
  final String attachmentName;
  final String attachmentMimeType;
  final String attachmentType;

  const MessageDetailScreen({
    super.key,
    required this.userId,
    required this.messageId,
    required this.senderName,
    required this.title,
    required this.body,
    required this.createdAtLabel,
    required this.isRead,
    required this.imageUrl,
    required this.imageName,
    required this.attachmentUrl,
    required this.attachmentName,
    required this.attachmentMimeType,
    required this.attachmentType,
  });

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);

  bool _isProcessingAttachmentAction = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    if (widget.isRead) return;

    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.userId)
          .collection('messages')
          .doc(widget.messageId)
          .set(
        <String, dynamic>{
          'isRead': true,
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    GoOutsSheet.info(context, title: 'GoOuts', message: message);
  }

  String _resolvedImageUrl() {
    final directImageUrl = widget.imageUrl.trim();
    if (directImageUrl.isNotEmpty) {
      return directImageUrl;
    }

    final normalizedAttachmentType = widget.attachmentType.trim().toLowerCase();
    final normalizedAttachmentUrl = widget.attachmentUrl.trim();

    if (normalizedAttachmentType == 'image' &&
        normalizedAttachmentUrl.isNotEmpty) {
      return normalizedAttachmentUrl;
    }

    return '';
  }

  String _resolvedAttachmentUrl() {
    final imageUrl = _resolvedImageUrl();
    if (imageUrl.isNotEmpty) {
      return imageUrl;
    }

    final normalizedAttachmentUrl = widget.attachmentUrl.trim();
    if (normalizedAttachmentUrl.isNotEmpty) {
      return normalizedAttachmentUrl;
    }

    return '';
  }

  bool _isImageAttachment() {
    return _resolvedImageUrl().isNotEmpty;
  }

  bool _hasAttachment() {
    return _resolvedAttachmentUrl().isNotEmpty;
  }

  bool _isPdfAttachment() {
    final mime = widget.attachmentMimeType.trim().toLowerCase();
    final type = widget.attachmentType.trim().toLowerCase();
    final name = widget.attachmentName.trim().toLowerCase();

    return mime.contains('pdf') || type == 'pdf' || name.endsWith('.pdf');
  }

  String _attachmentTitle() {
    if (_isImageAttachment()) {
      return 'Image';
    }

    if (_isPdfAttachment()) {
      return 'PDF Attachment';
    }

    return 'Attachment';
  }

  String _attachmentSubtitle() {
    if (_isImageAttachment()) {
      return 'Image attachment available';
    }

    final attachmentName = widget.attachmentName.trim();
    if (attachmentName.isNotEmpty) {
      return attachmentName;
    }

    if (_isPdfAttachment()) {
      return 'PDF file attached to this message';
    }

    return 'File attached to this message';
  }

  IconData _attachmentIcon() {
    if (_isPdfAttachment()) {
      return Icons.picture_as_pdf_outlined;
    }

    return Icons.attach_file_rounded;
  }

  String _attachmentActionLabel() {
    if (_isImageAttachment()) {
      return _isProcessingAttachmentAction ? 'Saving...' : 'Save to phone';
    }

    return _isProcessingAttachmentAction ? 'Opening...' : 'Open file';
  }

  Widget _attachmentActionLeadingWidget() {
    if (_isProcessingAttachmentAction) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _goOutsBlue,
        ),
      );
    }

    if (_isImageAttachment()) {
      return const Icon(
        Icons.download_rounded,
        size: 18,
      );
    }

    return const Icon(
      Icons.open_in_new_rounded,
      size: 18,
    );
  }

  Future<void> _handleAttachmentAction() async {
    final resolvedAttachmentUrl = _resolvedAttachmentUrl();

    if (resolvedAttachmentUrl.isEmpty) {
      _showSnackBar('No attachment available.');
      return;
    }

    if (_isProcessingAttachmentAction) {
      return;
    }

    setState(() {
      _isProcessingAttachmentAction = true;
    });

    try {
      if (_isImageAttachment()) {
        final bool? result = await GallerySaver.saveImage(resolvedAttachmentUrl);

        if (result == true) {
          GoOutsSheet.success(context, title: 'Saved', message: 'Image saved to your phone.');
        } else {
          GoOutsSheet.error(context, title: 'Save Failed', message: 'Could not save image.');
        }
      } else {
        final Uri uri = Uri.parse(resolvedAttachmentUrl);
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          _showSnackBar('Attachment opened.');
        } else {
          _showSnackBar('Could not open attachment.');
        }
      }
    } catch (e) {
      if (_isImageAttachment()) {
        _showSnackBar('Failed to save image.\n$e');
      } else {
        _showSnackBar('Failed to open attachment.\n$e');
      }
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessingAttachmentAction = false;
      });
    }
  }

  Widget _buildImageAttachmentSection() {
    final resolvedImageUrl = _resolvedImageUrl();

    if (resolvedImageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        const SizedBox(height: 16),
        Container(
          clipBehavior: Clip.antiAlias,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed:
                      _isProcessingAttachmentAction ? null : _handleAttachmentAction,
                  icon: _attachmentActionLeadingWidget(),
                  label: Text(_attachmentActionLabel()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _goOutsBlue,
                    side: const BorderSide(
                      color: _goOutsBlue,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF8FAFC),
                  child: Image.network(
                    resolvedImageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _goOutsBlue,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) {
                      return Container(
                        clipBehavior: Clip.antiAlias,
                        color: const Color(0xFFF8FAFC),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.broken_image_outlined,
                              size: 42,
                              color: Color(0xFF9CA3AF),
                            ),
                            SizedBox(height: 10),
                            AutoSizeText(
                              'Could not load image.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileAttachmentSection() {
    if (_isImageAttachment() || !_hasAttachment()) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        SizedBox(height: 16),
        Container(
          clipBehavior: Clip.antiAlias,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    clipBehavior: Clip.antiAlias,
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _goOutsBlue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _attachmentIcon(),
                      color: _goOutsBlue,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AutoSizeText(
                          _attachmentTitle(),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1F2937),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        AutoSizeText(
                          _attachmentSubtitle(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed:
                      _isProcessingAttachmentAction ? null : _handleAttachmentAction,
                  icon: _attachmentActionLeadingWidget(),
                  label: Text(_attachmentActionLabel()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _goOutsBlue,
                    side: const BorderSide(
                      color: _goOutsBlue,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        backgroundColor: _goOutsBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Message Detail',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        // Show "My Tickets" button when the message is support/ticket related:
        // – senderName contains "support", OR
        // – body contains a ticket number pattern like [SR-
        actions: (widget.senderName.toLowerCase().contains('support') ||
                  widget.body.contains('[SR-'))
            ? const [MyTicketsButton(invertColors: true)]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: <Widget>[
            Container(
              clipBehavior: Clip.antiAlias,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    clipBehavior: Clip.antiAlias,
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _goOutsBlue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.mail_outline_rounded,
                      color: _goOutsBlue,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AutoSizeText(
                          widget.senderName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        AutoSizeText(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 19,
                            color: Color(0xFF1F2937),
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 8),
                        AutoSizeText(
                          widget.createdAtLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _goOutsBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildImageAttachmentSection(),
            _buildFileAttachmentSection(),
            const SizedBox(height: 16),
            Container(
              clipBehavior: Clip.antiAlias,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.body,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}