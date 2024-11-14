# Saved segments

## Definitions

| Term | Definition |
|------|------------|
| **Segment Owner** | Usually the user who authored the segment |
| **Personal Segment** | A segment that has personal flag set as true and the user is the segment owner |
| **Personal Segments of Other Users** | A segment that has personal flag set as true and the user is not the segment owner |
| **Site Segment** | A segment that has personal flag set to false |
| **Segment Contents** | A list of filters |

## Capabilities

| Capability | Public | Viewer | Admin | Owner | Super Admin |
|------------|--------|--------|-------|-------|-------------|
| Can view data filtered by any segment they know the ID of | ✅ | ✅ | ✅ | ✅ | ✅ |
| Can see contents of any segment they know the ID of |  | ✅ | ✅ | ✅ | ✅ |
| Can make API requests filtered by any segment they know the ID of |  | ✅ | ✅ | ✅ | ✅ |
| Can create personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can see list of personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can edit personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can delete personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can set personal segments to be site segments [$] |  |  | ✅ | ✅ | ✅ |
| Can set site segments to be personal segments [$] |  |  | ✅ | ✅ | ✅ |
| Can see list of site segments [$] | ✅ | ✅ | ✅ | ✅ | ✅ |
| Can edit site segments [$] |  |  | ✅ | ✅ | ✅ |
| Can delete site segments [$] |  |  | ✅ | ✅ | ✅ |
| Can list personal segments of other users |  |  |  |  |  |
| Can edit personal segments of other users |  |  |  |  |  |
| Can delete personal segments of other users |  |  |  |  |  |

### Notes

* __[$]__: functionality available on Business plan or above

## Segment lifecycle

| Action | Outcome |
|--------|---------|
| A user* selects filters that constitute the segment, chooses name, chooses whether it's site segment or not*, clicks "update segment" | Segment created (with user as segment owner) |
| A user* views the contents of an existing segment, chooses name, chooses whether it's site segment or not*, clicks "save as new segment" | Segment created (with user as segment owner) |
| Segment owner* clicks edit segment, changes segment name or adds/removes/edits filters, chooses whether it's site segment or not*, clicks "update segment" | Segment updated |
| Any user* except the segment owner opens the segment for editing and clicks save, with or without changes | Segment updated (with the user becoming the new segment owner) |
| Segment owner* deletes segment | Segment deleted |
| Any user* except the segment owner deletes segment | Segment deleted |
| Site deleted | Segment deleted |
| Segment owner is removed from site or deleted from Plausible | If personal segment, segment deleted; if site segment, nothing happens |
| Any user* updates goal name, if site has any segments with "is goal ..." filters for that goal | Segment updated |
| Plausible engineer updates filters schema in backwards incompatible way | Segment updated |

### Notes

__*__: if the user has that particular capability

## Schema

| Field | Type | Constraints | Comment |
|-------|------|-------------|---------|
| :id | :bigint | null: false | |
| :name | :string | null: false | |
| :type | :enum | default: :personal, null: false | Possible values are :site, :personal. Needed to distinguish between segments that are supposed to be listed site-wide and ones that are listed only for author |
| :segment_data | :map | null: false | Contains the filters array at "filters" key and the labels record at "labels" key |
| :site_id | references(:sites) | on_delete: :delete_all, null: false | |
| :owner_id | references(:users) | on_delete: :nothing, null: false | Used to display author info without repeating author name and email in the database |
| timestamps() | | | Provides inserted_at, updated_at fields |

## API

[lib/plausible_web/router.ex](../../plausible_web/router.ex)