import 'package:flutter/material.dart';
import 'package:message_cal/services/database_service.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DatabaseService.instance.database;
      final result = await db.query(
        'pending_events', 
        orderBy: 'created_at DESC'
      );
      
      setState(() {
        _historyEvents = result;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'processing':
        return '처리중';
      case 'completed':
        return '완료';
      case 'failed':
        return '실패';
      default:
        return '알 수 없음';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'processing':
        return Icons.sync;
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  void _showEventDetail(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(event['status']),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(event['status']),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '등록 내역 상세',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // 스크롤 가능한 내용
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('상태', _getStatusText(event['status'])),
                          _buildDetailRow('등록일시', 
                            DateFormat('yyyy년 MM월 dd일 HH:mm').format(
                              DateTime.parse(event['created_at'])
                            )
                          ),
                          // 캘린더 등록 정보 (completed 상태일 때만)
                          if (event['status'] == 'completed') ...[
                            if (event['title'] != null)
                              _buildDetailRow('등록된 제목', event['title']),
                            if (event['event_date'] != null)
                              _buildDetailRow('등록된 날짜', event['event_date']),
                            if (event['event_time'] != null)
                              _buildDetailRow('등록된 시간', event['event_time']),
                            if (event['category'] != null)
                              _buildDetailRow('등록된 카테고리', event['category']),
                          ],
                          // 원본 메시지 (스크롤 가능)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '원본 메시지',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(
                                    minHeight: 100,
                                    maxHeight: 300,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      event['shared_text'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 액션 버튼들
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (event['status'] == 'failed') ...[
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _retryEvent(event);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryEvent(Map<String, dynamic> event) async {
    try {
      await DatabaseService.instance.updateEventStatus(event['id'], 'pending');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('다시 처리 대기열에 추가되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadHistory(); // 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('재시도 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('이 항목을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.deleteEvent(event['id']);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('항목이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        _loadHistory(); // 목록 새로고침
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('히스토리'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyEvents.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '등록된 히스토리가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '메시지를 공유하거나 수동으로 일정을 등록해보세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _historyEvents.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey.shade200,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final event = _historyEvents[index];
                          final createdAt = DateTime.parse(event['created_at']);
                          
                          return Container(
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(event['status']),
                                child: Icon(
                                  _getStatusIcon(event['status']),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                event['shared_text'].length > 30
                                    ? '${event['shared_text'].substring(0, 30)}...'
                                    : event['shared_text'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '상태: ${_getStatusText(event['status'])}',
                                    style: TextStyle(
                                      color: _getStatusColor(event['status']),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MM/dd HH:mm').format(createdAt),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'detail':
                                      _showEventDetail(event);
                                      break;
                                    case 'retry':
                                      _retryEvent(event);
                                      break;
                                    case 'delete':
                                      _deleteEvent(event);
                                      break;
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  final items = <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'detail',
                                      child: Row(
                                        children: [
                                          Icon(Icons.info, size: 16),
                                          SizedBox(width: 8),
                                          Text('상세보기'),
                                        ],
                                      ),
                                    ),
                                  ];
                                  
                                  if (event['status'] == 'failed') {
                                    items.add(
                                      const PopupMenuItem<String>(
                                        value: 'retry',
                                        child: Row(
                                          children: [
                                            Icon(Icons.refresh, size: 16),
                                            SizedBox(width: 8),
                                            Text('다시 시도'),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  items.add(
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('삭제', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  );
                                  
                                  return items;
                                },
                              ),
                              onTap: () => _showEventDetail(event),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
    );
  }
}