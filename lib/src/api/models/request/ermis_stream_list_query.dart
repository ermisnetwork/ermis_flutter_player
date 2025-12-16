class ErmisStreamListQuery {
  const ErmisStreamListQuery({
    this.page = 1,
    this.perPage = 20,
    this.sortBy = 'stream_id',
    this.sortOrder = 'asc',
  });

  final int page;
  final int perPage;
  final String sortBy;
  final String sortOrder;

  Map<String, dynamic> toJson() => {
        'page': page,
        'per_page': perPage,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
}
