# WikiLex

A fast, high-performance dictionary service powered by Wikipedia. Features in-memory indexing with cloud-native storage to serve millions of word lookups with cost-effective, low-latency reads.

## Features

- **High Performance** - Sub-40ms p99 latency with in-memory index lookups
- **Cost Efficient** - Object storage + byte-range reads for minimal infrastructure cost
- **Scalable** - Handles 100K to 10M+ lookups per month
- **Zero Downtime Updates** - Blue-green deployment for safe, atomic data refreshes
- **Simple Operations** - Minimal moving parts, easy to maintain

## Architecture

The service uses a read-optimized architecture:

- **In-memory index** (~50MB) for O(1) key lookups
- **GCS Standard storage** for immutable data files
- **Byte-range HTTP reads** for precise value retrieval
- **Weekly changelog updates** with atomic version switching

## Tech Stack

- Google Cloud Platform (GCS)
- Docker

## Documentation

- [Architecture Review Board (ARB)](docs/architecture_review_board_arb_read_optimized_dictionary_system.md)

## License

MIT
