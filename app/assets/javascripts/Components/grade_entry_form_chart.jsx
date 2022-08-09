import React from "react";
import {AssessmentChart, FractionStat} from "./assessment_chart";

export class GradeEntryFormChart extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      summary: {
        average: null,
        median: null,
        num_submissions_collected: null,
        num_submissions_graded: null,
        num_fails: null,
        num_zeros: null,
        groupings_size: null,
      },
      grade_entry_form_distribution: {
        data: {
          labels: [],
          datasets: [],
        },
      },
      column_summary: [],
      column_grade_distribution: {
        data: {
          labels: [],
          datasets: [],
        },
      },
    };
  }

  componentDidMount() {
    this.fetchData();
  }

  fetchData = () => {
    fetch(
      Routes.grade_distribution_course_grade_entry_form_path(
        this.props.course_id,
        this.props.assessment_id
      )
    )
      .then(data => data.json())
      .then(res => {
        for (const [index, element] of res.column_breakdown_data.datasets.entries()) {
          element.backgroundColor = colours[index];
        }
        this.setState({
          summary: res.info_summary,
          column_summary: res.column_summary,
          grade_entry_form_distribution: {
            data: res.grade_dist_data,
          },
          column_grade_distribution: {
            data: res.column_breakdown_data,
          },
        });
      });
  };

  componentDidUpdate(prevProps, prevState) {
    if (prevProps.assessment_id !== this.props.assessment_id) {
      this.fetchData();
    }
  }

  render() {
    return (
      <AssessmentChart
        assessment_header_content={
          <a
            href={Routes.edit_course_grade_entry_form_path(
              this.props.course_id,
              this.props.assessment_id
            )}
          >
            {this.props.show_chart_header ? this.state.summary.name : ""}
          </a>
        }
        summary={this.state.summary}
        assessment_data={this.state.grade_entry_form_distribution.data}
        additional_assessment_stats={
          <React.Fragment>
            <span className="summary-stats-label">{I18n.t("attributes.date")}</span>
            <span>{this.state.summary.date}</span>
            <span className="summary-stats-label">{I18n.t("num_entries")}</span>
            <FractionStat
              numerator={this.state.summary.num_entries}
              denominator={this.state.summary.groupings_size}
            />
          </React.Fragment>
        }
        show_grade_breakdown_chart={true}
        show_grade_breakdown_table={this.props.show_column_table}
        grade_breakdown_distribution_title={I18n.t(
          "grade_entry_forms.grade_entry_item_distribution"
        )}
        grade_breakdown_summary={this.state.column_summary}
        grade_breakdown_distribution_data={this.state.column_grade_distribution.data}
        grade_breakdown_assign_link={
          <a
            href={Routes.edit_course_grade_entry_form_path(
              this.props.course_id,
              this.props.assessment_id
            )}
          >
            {I18n.t("helpers.submit.create", {
              model: I18n.t("activerecord.models.grade_entry_item.one"),
            })}
          </a>
        }
      />
    );
  }
}
