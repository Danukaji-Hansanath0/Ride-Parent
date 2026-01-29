# Vehicle Service - Entity Relationships Documentation

## 📊 Entity Relationship Overview

This document describes the JPA entity relationships in the Vehicle Service, including cascade types, fetch strategies, and relationship mappings.

---

## 🔗 Relationship Diagram

```
Makes (1) ──────< CarModels (Many)
  │                    │
  │                    │
  └──< Vehicle >───────┘
         │
         │
         ▼
  OwnersHasVehicle (Junction Table)
         │
         │
         ▼
  VehicleOwners
```

---

## 📋 Entity Details

### 1. **Vehicle** (Main Entity)
**Table:** `vehicles`  
**Primary Key:** `UUID id` (Auto-generated)

#### Relationships:
- **@ManyToOne → Makes**
  - `fetch = FetchType.LAZY` - Performance optimization
  - `optional = false` - Make is required
  - Join Column: `make_id`
  
- **@ManyToOne → CarModels**
  - `fetch = FetchType.LAZY` - Performance optimization
  - `optional = false` - Model is required
  - Join Column: `model_id`
  
- **@OneToMany → OwnersHasVehicle**
  - `mappedBy = "vehicle"` - Bidirectional relationship
  - `cascade = CascadeType.ALL` - All operations cascade to children
  - `orphanRemoval = true` - Delete orphaned records
  - `fetch = FetchType.LAZY` - Load owners on demand

#### Fields:
- Basic Info: `year`, `submodel`
- Technical Specs: `transmission`, `fuelType`, `seats`, `doors`, `drivetrain`
- Engine: `engineType`, `engineDisplacement`
- Timestamps: `createdAt`, `updatedAt`

---

### 2. **Makes** (Vehicle Manufacturer)
**Table:** `makes`  
**Primary Key:** `Long id` (Auto-generated)

#### Relationships:
- **@OneToMany → CarModels**
  - `mappedBy = "make"` - Bidirectional relationship
  - `cascade = CascadeType.ALL` - Cascade all operations
  - `orphanRemoval = true` - Delete orphaned models
  - `fetch = FetchType.LAZY` - Load models on demand

#### Fields:
- `name` (String, unique, max 100 chars)

#### Constraints:
- Unique constraint on `name`

---

### 3. **CarModels** (Vehicle Model)
**Table:** `car_models`  
**Primary Key:** `UUID id` (Auto-generated)

#### Relationships:
- **@ManyToOne → Makes**
  - `fetch = FetchType.LAZY` - Performance optimization
  - `optional = false` - Make is required
  - Join Column: `make_id`

#### Fields:
- `name` (String, max 100 chars)

#### Constraints:
- Unique constraint on `name` + `make_id` combination

---

### 4. **OwnersHasVehicle** (Junction Table)
**Table:** `owners_has_vehicles`  
**Primary Key:** `UUID id` (Auto-generated)

#### Purpose:
Represents the many-to-many relationship between VehicleOwners and Vehicles.

#### Relationships:
- **@ManyToOne → VehicleOwners**
  - `fetch = FetchType.LAZY` - Performance optimization
  - `optional = false` - Owner is required
  - Join Column: `owner_id`
  
- **@ManyToOne → Vehicle**
  - `fetch = FetchType.LAZY` - Performance optimization
  - `optional = false` - Vehicle is required
  - Join Column: `vehicle_id`

---

### 5. **VehicleOwners** (Owner Information)
**Table:** `vehicle_owners`  
**Primary Key:** `UUID id` (Auto-generated)

#### Relationships:
- **@OneToMany → OwnersHasVehicle**
  - `mappedBy = "owner"` - Bidirectional relationship
  - `cascade = CascadeType.ALL` - Cascade all operations
  - `orphanRemoval = true` - Delete orphaned relationships
  - `fetch = FetchType.LAZY` - Load vehicles on demand

#### Fields:
- `isFranchiseOwner` (boolean)
- `franchiseId` (String)
- `ownerId` (String)
- Timestamps: `createdAt`, `updatedAt`

---

## 🎯 Cascade Types Explained

### CascadeType.ALL
Used in parent-child relationships where the parent owns the lifecycle of children:
- **Makes → CarModels**: Deleting a make deletes all its models
- **Vehicle → OwnersHasVehicle**: Deleting a vehicle removes ownership records
- **VehicleOwners → OwnersHasVehicle**: Deleting an owner removes their vehicle associations

### No Cascade
Used in relationships where entities have independent lifecycles:
- **Vehicle → Makes**: Deleting a vehicle doesn't delete the make
- **Vehicle → CarModels**: Deleting a vehicle doesn't delete the model
- **CarModels → Makes**: Deleting a model doesn't delete the make

---

## 🚀 Fetch Strategies

### LAZY Loading (All relationships)
All relationships use `FetchType.LAZY` for optimal performance:
- Associated entities are loaded only when accessed
- Prevents N+1 query problems when listing entities
- Reduces initial query payload size

**Important:** Ensure proper transaction boundaries when accessing lazy-loaded collections.

---

## ⚡ Performance Considerations

### 1. **Lazy Loading**
- All collections use `FetchType.LAZY`
- Use `@Transactional` on service methods that access lazy collections
- Consider using JOIN FETCH in JPQL queries for specific use cases

### 2. **Orphan Removal**
- `orphanRemoval = true` automatically deletes child records when removed from parent collection
- Reduces manual cleanup code
- Ensures database integrity

### 3. **Bidirectional Relationships**
- Use `mappedBy` on the owning side
- Prevents duplicate foreign key columns
- Maintains consistency between both sides of the relationship

---

## 🔒 Constraints & Validations

### Database Level:
1. **Makes**: Unique constraint on `name`
2. **CarModels**: Composite unique constraint on `(name, make_id)`
3. **Foreign Keys**: All relationships have NOT NULL foreign keys where `optional=false`

### JPA Level:
1. **Nullable Fields**: Controlled by `nullable` parameter
2. **Required Relationships**: Controlled by `optional` parameter
3. **Cascade Operations**: Controlled by `cascade` parameter

---

## 📝 Best Practices Applied

### ✅ Proper Relationship Mapping
- Bidirectional relationships use `mappedBy`
- Foreign key ownership is clearly defined
- Join columns explicitly named

### ✅ Performance Optimization
- Lazy loading for all relationships
- Proper use of cascade types
- Orphan removal where appropriate

### ✅ Data Integrity
- NOT NULL constraints on required relationships
- Unique constraints on business keys
- Proper equals/hashCode implementation using Hibernate-aware patterns

### ✅ Clean Code
- Lombok annotations reduce boilerplate
- Builder pattern for entity creation
- Proper entity lifecycle management

---

## 🧪 Testing Recommendations

### Unit Tests:
1. Test cascade operations (save, delete)
2. Verify orphan removal
3. Test lazy loading behavior
4. Validate unique constraints

### Integration Tests:
1. Test relationship persistence
2. Verify foreign key constraints
3. Test transaction boundaries
4. Validate bidirectional sync

---

## 🔄 Migration Notes

If updating an existing database, ensure:
1. All foreign key columns exist and are properly indexed
2. Unique constraints are created
3. NOT NULL constraints are applied after data validation
4. Orphaned records are cleaned up before enabling `orphanRemoval`

---

## 📚 Related Files

- `Vehicle.java` - Main vehicle entity
- `Makes.java` - Vehicle manufacturer entity
- `CarModels.java` - Vehicle model entity
- `OwnersHasVehicle.java` - Junction table entity
- `VehicleOwners.java` - Owner information entity

---

## ✅ Verification Checklist

- [x] All ManyToOne relationships have `fetch = FetchType.LAZY`
- [x] All ManyToOne relationships have `optional = false` where required
- [x] All OneToMany relationships use `mappedBy`
- [x] Parent-child relationships have `CascadeType.ALL` and `orphanRemoval = true`
- [x] Independent relationships have no cascade
- [x] All join columns are explicitly named
- [x] All entities have proper equals/hashCode
- [x] All entities have Lombok annotations
- [x] All entities have timestamps where appropriate
- [x] All unique constraints are defined

---

**Last Updated:** January 16, 2026  
**Author:** Vehicle Service Development Team  
**Status:** ✅ Ready for Production
