package com.selimhorri.app.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.client.RestTemplate;

import com.selimhorri.app.domain.Favourite;
import com.selimhorri.app.domain.id.FavouriteId;
import com.selimhorri.app.dto.FavouriteDto;
import com.selimhorri.app.exception.wrapper.FavouriteNotFoundException;
import com.selimhorri.app.repository.FavouriteRepository;

/**
 * Unit tests for FavouriteServiceImpl
 * Tests validate favourite service operations and user-product relationships
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("Favourite Service Unit Tests")
class FavouriteServiceImplTest {

    @Mock
    private FavouriteRepository favouriteRepository;

    @Mock
    private RestTemplate restTemplate;

    @InjectMocks
    private FavouriteServiceImpl favouriteService;

    private Favourite testFavourite;
    private FavouriteDto testFavouriteDto;
    private FavouriteId testFavouriteId;

    @BeforeEach
    void setUp() {
        // Setup test favourite ID
        testFavouriteId = new FavouriteId(1, 1, LocalDateTime.now());

        // Setup test favourite
        testFavourite = Favourite.builder()
            .userId(1)
            .productId(1)
            .likeDate(LocalDateTime.now())
            .build();

        // Setup test favourite DTO
        testFavouriteDto = FavouriteDto.builder()
            .userId(1)
            .productId(1)
            .likeDate(LocalDateTime.now())
            .build();
    }

    @Test
    @DisplayName("Test 1: Find all favourites should return list of FavouriteDto")
    void testFindAll_ShouldReturnListOfFavourites() {
        // Given
        Favourite favourite2 = Favourite.builder()
            .userId(1)
            .productId(2)
            .likeDate(LocalDateTime.now())
            .build();

        when(favouriteRepository.findAll()).thenReturn(Arrays.asList(testFavourite, favourite2));

        // When
        List<FavouriteDto> result = favouriteService.findAll();

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(2, result.size(), "Should return 2 favourites");
        verify(favouriteRepository, times(1)).findAll();
    }

    @Test
    @DisplayName("Test 2: Find favourite by ID should return FavouriteDto when favourite exists")
    void testFindById_WhenFavouriteExists_ShouldReturnFavouriteDto() {
        // Given
        when(favouriteRepository.findById(testFavouriteId)).thenReturn(Optional.of(testFavourite));

        // When
        FavouriteDto result = favouriteService.findById(testFavouriteId);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(testFavourite.getUserId(), result.getUserId(), "User IDs should match");
        assertEquals(testFavourite.getProductId(), result.getProductId(), "Product IDs should match");
        verify(favouriteRepository, times(1)).findById(testFavouriteId);
    }

    @Test
    @DisplayName("Test 3: Find favourite by ID should throw exception when favourite not found")
    void testFindById_WhenFavouriteNotExists_ShouldThrowException() {
        // Given
        FavouriteId nonExistentId = new FavouriteId(999, 999, LocalDateTime.now());
        when(favouriteRepository.findById(nonExistentId)).thenReturn(Optional.empty());

        // When & Then
        FavouriteNotFoundException exception = assertThrows(
            FavouriteNotFoundException.class,
            () -> favouriteService.findById(nonExistentId),
            "Should throw FavouriteNotFoundException"
        );

        assertTrue(exception.getMessage().contains("not found"), "Exception message should contain 'not found'");
        verify(favouriteRepository, times(1)).findById(nonExistentId);
    }

    @Test
    @DisplayName("Test 4: Save favourite should persist and return FavouriteDto")
    void testSave_ShouldPersistAndReturnFavouriteDto() {
        // Given
        when(favouriteRepository.save(any(Favourite.class))).thenReturn(testFavourite);

        // When
        FavouriteDto result = favouriteService.save(testFavouriteDto);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(testFavouriteDto.getUserId(), result.getUserId(), "User IDs should match");
        assertEquals(testFavouriteDto.getProductId(), result.getProductId(), "Product IDs should match");
        assertNotNull(result.getLikeDate(), "Like date should not be null");
        verify(favouriteRepository, times(1)).save(any(Favourite.class));
    }

    @Test
    @DisplayName("Test 5: Update favourite should modify and return updated FavouriteDto")
    void testUpdate_ShouldModifyAndReturnFavouriteDto() {
        // Given
        LocalDateTime newLikeDate = LocalDateTime.now().plusDays(1);
        FavouriteDto updatedFavouriteDto = FavouriteDto.builder()
            .userId(1)
            .productId(1)
            .likeDate(newLikeDate)
            .build();

        Favourite updatedFavourite = Favourite.builder()
            .userId(1)
            .productId(1)
            .likeDate(newLikeDate)
            .build();

        when(favouriteRepository.save(any(Favourite.class))).thenReturn(updatedFavourite);

        // When
        FavouriteDto result = favouriteService.update(updatedFavouriteDto);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(newLikeDate, result.getLikeDate(), "Like date should be updated");
        verify(favouriteRepository, times(1)).save(any(Favourite.class));
    }

    @Test
    @DisplayName("Test 6: Delete favourite by ID should invoke repository delete")
    void testDeleteById_ShouldInvokeRepositoryDelete() {
        // Given
        doNothing().when(favouriteRepository).deleteById(testFavouriteId);

        // When
        favouriteService.deleteById(testFavouriteId);

        // Then
        verify(favouriteRepository, times(1)).deleteById(testFavouriteId);
    }

    @Test
    @DisplayName("Test 7: Find all favourites with empty list should return empty result")
    void testFindAll_WhenNoFavourites_ShouldReturnEmptyList() {
        // Given
        when(favouriteRepository.findAll()).thenReturn(Arrays.asList());

        // When
        List<FavouriteDto> result = favouriteService.findAll();

        // Then
        assertNotNull(result, "Result should not be null");
        assertTrue(result.isEmpty(), "Result should be empty");
        verify(favouriteRepository, times(1)).findAll();
    }

    @Test
    @DisplayName("Test 8: Save favourite should set current timestamp when likeDate is null")
    void testSave_WhenLikeDateIsNull_ShouldSetCurrentTimestamp() {
        // Given
        FavouriteDto favouriteWithoutDate = FavouriteDto.builder()
            .userId(2)
            .productId(2)
            .likeDate(null)
            .build();

        Favourite savedFavourite = Favourite.builder()
            .userId(2)
            .productId(2)
            .likeDate(LocalDateTime.now())
            .build();

        when(favouriteRepository.save(any(Favourite.class))).thenReturn(savedFavourite);

        // When
        FavouriteDto result = favouriteService.save(favouriteWithoutDate);

        // Then
        assertNotNull(result, "Result should not be null");
        assertNotNull(result.getLikeDate(), "Like date should be set automatically");
        verify(favouriteRepository, times(1)).save(any(Favourite.class));
    }

    @Test
    @DisplayName("Test 9: Save multiple favourites for same user should succeed")
    void testSave_MultipleProductsForSameUser_ShouldSucceed() {
        // Given
        FavouriteDto favourite1 = FavouriteDto.builder()
            .userId(1)
            .productId(1)
            .likeDate(LocalDateTime.now())
            .build();

        FavouriteDto favourite2 = FavouriteDto.builder()
            .userId(1)
            .productId(2)
            .likeDate(LocalDateTime.now())
            .build();

        Favourite savedFavourite1 = Favourite.builder()
            .userId(1)
            .productId(1)
            .likeDate(LocalDateTime.now())
            .build();

        Favourite savedFavourite2 = Favourite.builder()
            .userId(1)
            .productId(2)
            .likeDate(LocalDateTime.now())
            .build();

        when(favouriteRepository.save(any(Favourite.class)))
            .thenReturn(savedFavourite1)
            .thenReturn(savedFavourite2);

        // When
        FavouriteDto result1 = favouriteService.save(favourite1);
        FavouriteDto result2 = favouriteService.save(favourite2);

        // Then
        assertNotNull(result1, "First result should not be null");
        assertNotNull(result2, "Second result should not be null");
        assertEquals(1, result1.getUserId(), "User ID should match");
        assertEquals(1, result1.getProductId(), "First product ID should be 1");
        assertEquals(2, result2.getProductId(), "Second product ID should be 2");
        verify(favouriteRepository, times(2)).save(any(Favourite.class));
    }
}

