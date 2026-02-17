# ABCD-ReproSchema

ReproSchema conversion of the **Adolescent Brain Cognitive Development (ABCD)** Study data dictionary from [NBDC - NIH Brain Development Cohorts](https://github.com/nbdc-datahub/NBDCtoolsData).

## What is ReproSchema?

[ReproSchema](https://github.com/ReproNim/reproschema) is an open standard for creating machine-readable, reproducible assessments and data dictionaries. It uses JSON-LD format to describe surveys, questionnaires, and data collection instruments in a way that enables interoperability across studies and platforms.

> Chen Y, Jarecka D, Abraham S, Gau R, Ng E, Low D, Bevers I, Johnson A, Keshavan A, Klein A, Clucas J, Rosli Z, Hodge S, Linkersdorfer J, Bartsch H, Das S, Fair D, Kennedy D, Ghosh S. Standardizing Survey Data Collection to Enhance Reproducibility: Development and Comparative Evaluation of the ReproSchema Ecosystem. J Med Internet Res 2025;27:e63343. URL: https://www.jmir.org/2025/1/e63343. DOI: 10.2196/63343

## Repository Structure

```
ABCD-ReproSchema/
├── ABCD/                       # ReproSchema output
│   ├── ABCD/
│   │   └── ABCD_schema         # Protocol schema
│   └── activities/             # Activity directories
│       └── [activity_name]/
│           ├── [activity]_schema
│           └── items/
├── scripts/
│   ├── convert.py              # Conversion wrapper
│   └── extract_release.R       # Extraction script
├── abcd_nbdc2rs.yaml           # Protocol metadata
├── .github/workflows/
│   └── convert.yml             # CI/CD workflow
└── README.md
```

## Versions

Each ABCD data release is tagged:

```bash
git clone --branch 6.0 https://github.com/ReproNim/ABCD-ReproSchema.git
```

Available releases: See [Tags](../../tags)

## Related Projects

- [HBCD-ReproSchema](https://github.com/ReproNim/HBCD-ReproSchema) - ReproSchema conversion for HBCD Study
- [reproschema-py](https://github.com/ReproNim/reproschema-py) - Python library for ReproSchema
- [NBDCtoolsData](https://github.com/nbdc-datahub/NBDCtoolsData) - Source data dictionaries

## License

MIT
