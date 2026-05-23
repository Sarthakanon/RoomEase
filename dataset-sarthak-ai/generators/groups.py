import numpy as np
import pandas as pd
from datetime import date, timedelta
from typing import List, Dict, Tuple
from config import GenerationConfig, GroupType, GROUP_TYPE_PARAMS
from models import Group, GroupMembership
from algorithms.groups import (
    generate_group_birthdays, generate_group_type, assign_group_members,
    determine_group_split_method, compute_group_dormancy, generate_group_name,
)


def generate_groups_and_memberships(
    config: GenerationConfig, user_ids: List[str]
) -> Tuple[List[Group], List[GroupMembership]]:
    rng = np.random.default_rng(config.seed + 5000)

    start_date = date.fromisoformat(config.start_date)
    end_date = date.fromisoformat(config.end_date)

    num_groups = config.num_groups_target
    creation_dates = generate_group_birthdays(start_date, end_date, num_groups, rng)

    groups = []
    memberships = []
    membership_id = 0

    for i, created_date in enumerate(creation_dates):
        group_rng = np.random.default_rng(config.seed + 5000 + i)
        group_type = generate_group_type(group_rng)
        params = GROUP_TYPE_PARAMS[group_type]

        name = generate_group_name(group_type, group_rng)
        split_method = determine_group_split_method(group_type, group_rng)

        lifespan_months, becomes_dormant = compute_group_dormancy(created_date, group_type, group_rng)
        lifespan_months = int(lifespan_months)

        end_of_life = created_date + timedelta(days=lifespan_months * 30)
        if end_of_life > end_date:
            status = "active"
        elif becomes_dormant:
            dormancy_start = created_date + timedelta(days=int(lifespan_months * 30 * 0.7))
            if dormancy_start < end_date:
                status = "dormant"
            else:
                status = "active"
        else:
            status = "ended"

        group = Group(
            group_id=f"GRP_{i+1:04d}",
            name=name,
            group_type=group_type,
            created_date=created_date,
            status=status,
            default_split_method=split_method,
            description=f"{group_type.value} group",
        )
        groups.append(group)

        member_ids = assign_group_members(group_type, user_ids, group_rng)
        roles = ["admin", "member", "member", "member"]

        for j, uid in enumerate(member_ids):
            join_delay = int(group_rng.integers(0, 30))
            member_join = created_date + timedelta(days=join_delay)
            if member_join > end_date:
                continue

            left_date = None
            if status in ["ended", "dormant"] and group_rng.random() < 0.3:
                leave_days = int(group_rng.integers(30, max(31, lifespan_months * 30)))
                left_date = created_date + timedelta(days=leave_days)
                if left_date > end_date:
                    left_date = None

            share_pct = round(1.0 / len(member_ids), 4) if split_method == "equal" else round(group_rng.uniform(0.05, 0.4), 4)

            membership = GroupMembership(
                membership_id=f"MEM_{membership_id+1:06d}",
                group_id=group.group_id,
                user_id=uid,
                joined_date=member_join,
                left_date=left_date,
                role=roles[min(j, len(roles) - 1)],
                share_percentage=share_pct,
            )
            memberships.append(membership)
            membership_id += 1

    user_group_counts = {}
    for m in memberships:
        user_group_counts[m.user_id] = user_group_counts.get(m.user_id, 0) + 1

    avg = sum(user_group_counts.values()) / max(len(user_group_counts), 1)

    return groups, memberships


def groups_to_dataframe(groups: List[Group]) -> pd.DataFrame:
    rows = []
    for g in groups:
        rows.append({
            "group_id": g.group_id,
            "name": g.name,
            "group_type": g.group_type.value,
            "created_date": g.created_date.isoformat(),
            "status": g.status,
            "default_split_method": g.default_split_method,
            "description": g.description,
        })
    return pd.DataFrame(rows)


def memberships_to_dataframe(memberships: List[GroupMembership]) -> pd.DataFrame:
    rows = []
    for m in memberships:
        rows.append({
            "membership_id": m.membership_id,
            "group_id": m.group_id,
            "user_id": m.user_id,
            "joined_date": m.joined_date.isoformat(),
            "left_date": m.left_date.isoformat() if m.left_date else "",
            "role": m.role,
            "share_percentage": m.share_percentage,
        })
    return pd.DataFrame(rows)