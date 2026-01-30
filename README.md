# ABCD-ReproSchema

ABCD (Adolescent Brain Cognitive Development) study assessments in [ReproSchema](https://github.com/ReproNim/reproschema) format.

## Structure

```
ABCD/
├── ABCD/
│   └── ABCD_schema       # Protocol schema
└── activities/           # Individual assessments
    └── [assessment]/
        ├── [assessment]_schema
        └── items/
            └── [item]
```

## Versions

Each ABCD data release is tagged. To use a specific version:

```bash
# Clone a specific release
git clone --branch 6.0 https://github.com/ReproNim/ABCD-ReproSchema.git

# Or checkout after cloning
git checkout 6.0
```

Available releases: See [Tags](../../tags)

## Related

- [ReproSchema](https://github.com/ReproNim/reproschema) - Schema specification
- [reproschema-py](https://github.com/ReproNim/reproschema-py) - Python tools for ReproSchema

## License

MIT
